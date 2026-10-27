#!/usr/bin/env python3
"""Report what has changed on main and in the issues: merged PRs and task issues.

Every session runs this before starting work and before its final report, then
tells its user the result in a few lines (see CLAUDE.md and CONTRIBUTING.md).

    python3 scripts/progress.py --login shmurkles   # since your last commit or merge
    python3 scripts/progress.py --since 3a1b2c4      # since a commit
    python3 scripts/progress.py --since 2026-10-27   # since a date (UTC)
    python3 scripts/progress.py --since 12h          # since 12 hours ago (or 3d)
    python3 scripts/progress.py                      # since 24 hours ago

Needs git, and gh signed in for the issue and pull request parts.
"""
import argparse
from datetime import datetime, timezone
import json
import re
import signal
import subprocess
import sys

BRANCH = "origin/main"
CLAIM = "in progress"


def git(*args, check=True):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout if result.returncode == 0 else None


def short(text, width=90):
    text = text.replace("`", "")
    return text if len(text) <= width else text[: width - 1] + "…"


def repo():
    url = git("remote", "get-url", "origin", check=False) or ""
    match = re.search(r"github\.com[:/]([^/]+)/([^/.\s]+)", url)
    return f"{match.group(1)}/{match.group(2)}" if match else None


def gh(path):
    """GET a GitHub API path with gh; None if gh is missing or fails."""
    try:
        out = subprocess.run(["gh", "api", path], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return json.loads(out.stdout) if out.returncode == 0 else None


def resolve_since(since, login):
    if login:
        for line in (git("log", BRANCH, "--format=%H\t%an\t%cn") or "").splitlines():
            sha, author, committer = line.split("\t")
            if login.lower() in (author.lower(), committer.lower()):
                return sha, f"your last commit or merge as {login}"
        print(f"No commit by {login} found in fetched history; showing the last 24 hours.\n")
        since = "24h"
    since = since or "24h"
    relative = re.fullmatch(r"(\d+)([hd])", since)
    if relative or re.fullmatch(r"\d{4}-\d{2}-\d{2}.*", since):
        before = (f"{relative.group(1)} {'hours' if relative.group(2) == 'h' else 'days'} ago"
                  if relative else since)
        sha = git("rev-list", "-1", f"--before={before}", BRANCH).strip()
        if not sha:
            sha = git("rev-list", "--max-parents=0", BRANCH).split()[-1]
        return sha, f"{since}"
    sha = git("rev-parse", "--verify", since + "^{commit}", check=False)
    if not sha:
        sys.exit(f"Unknown commit {since!r}. Fetch more history: git fetch --depth=500 origin main")
    return sha.strip(), f"commit {since}"


def issue_changes(name, since_iso):
    """Issues done, claimed, released and added since a UTC time, from the issue events."""
    changes = {"Done": {}, "Claimed": {}, "Released": {}, "New": {}}
    for page in range(1, 11):
        events = gh(f"repos/{name}/issues/events?per_page=100&page={page}")
        if events is None:
            return None
        for event in events:
            if event["created_at"] < since_iso:
                return changes, True
            issue = event.get("issue") or {}
            if not issue or issue.get("pull_request"):
                continue
            number, title = issue["number"], short(issue["title"])
            label = (event.get("label") or {}).get("name")
            if event["event"] == "closed" and issue.get("state_reason") == "completed":
                changes["Done"].setdefault(number, f"  #{number} {title}")
            elif event["event"] == "labeled" and label == CLAIM:
                who = ", ".join(a["login"] for a in issue.get("assignees") or []) or event["actor"]["login"]
                changes["Claimed"].setdefault(number, f"  #{number} {title}: {who}")
            elif event["event"] == "unlabeled" and label == CLAIM and issue["state"] == "open":
                changes["Released"].setdefault(number, f"  #{number} {title}")
        if len(events) < 100:
            break
    created = gh(f"repos/{name}/issues?state=all&since={since_iso}&per_page=100") or []
    for issue in created:
        if not issue.get("pull_request") and issue["created_at"] >= since_iso:
            changes["New"][issue["number"]] = f"  #{issue['number']} {short(issue['title'])} [{issue['state']}]"
    return changes, False


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--since", help="commit, date (YYYY-MM-DD) or age (12h, 3d)")
    parser.add_argument("--login", help="GitHub login: report since that person's last commit or merge")
    args = parser.parse_args()

    git("fetch", "--quiet", "--depth=500", "origin", "main", check=False)
    since, label = resolve_since(args.since, args.login)
    head = git("rev-parse", BRANCH).strip()
    date = git("show", "-s", "--format=%cd", "--date=format:%Y-%m-%d %H:%M UTC", since).strip()
    stamp = git("show", "-s", "--format=%cI", since).strip()
    since_iso = datetime.fromisoformat(stamp).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"Progress since {label} ({since[:7]}, {date}):\n")
    if since == head:
        print("Nothing new on main.")

    merges, direct = [], []
    for record in (git("log", "--first-parent", "--format=%H%x1f%P%x1f%s%x1f%b%x1e", f"{since}..{head}") or "").split("\x1e"):
        if not record.strip():
            continue
        sha, parents, subject, body = record.strip("\n").split("\x1f")
        pr = re.match(r"Merge pull request #(\d+) from \S+", subject)
        if pr and len(parents.split()) > 1:
            merges.append(f"  #{pr.group(1)} {body.strip().splitlines()[0] if body.strip() else subject}")
        elif not subject.startswith("roadmap:"):
            direct.append(f"  {sha[:7]} {subject}")
    if merges:
        print("Merged pull requests:")
        print("\n".join(reversed(merges)))
    if direct:
        print("Other commits to main:")
        print("\n".join(reversed(direct)))

    name = repo()
    found = issue_changes(name, since_iso) if name else None
    if found is None:
        print("\n(gh isn't available or signed in, so issues and open PRs aren't listed.)")
        return
    changes, complete = found
    titles = {"Done": "Issues done", "Claimed": "Issues claimed", "Released": "Issues released (free again)",
              "New": "New issues"}
    for key, lines in changes.items():
        if lines:
            print(f"{titles[key]}:")
            print("\n".join(lines.values()))
    if not complete:
        print("(Only the latest 1,000 issue events were read; older changes may be missing.)")

    open_issues = gh(f"repos/{name}/issues?state=open&per_page=100") or []
    issues = [i for i in open_issues if not i.get("pull_request")]
    has = lambda issue, name: any(l["name"] == name for l in issue["labels"])
    busy = [i for i in issues if has(i, CLAIM)]
    blocked = sum(1 for i in issues if has(i, "blocked") and not has(i, CLAIM))
    print(f"\nIssues now: {len(issues) - len(busy) - blocked} open, {len(busy)} in progress, {blocked} blocked")
    if busy:
        print("In progress now (leave these and their Touches files alone):")
        for issue in busy:
            who = ", ".join(a["login"] for a in issue["assignees"]) or "unassigned"
            print(f"  #{issue['number']} {short(issue['title'], 60)}: {who}")
    pulls = gh(f"repos/{name}/pulls?state=open")
    if pulls:
        print("Open pull requests:")
        for pull in pulls:
            print(f"  #{pull['number']} {pull['title']} ({pull['head']['ref']})")


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # exit quietly when piped into head
    main()
