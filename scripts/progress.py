#!/usr/bin/env python3
"""Report what has changed on main: merged pull requests and roadmap rows.

Every session runs this before starting work and before its final report, then
tells its user the result in a few lines (see CLAUDE.md).

    python3 scripts/progress.py --login shmurkles   # since your last roadmap edit or merge
    python3 scripts/progress.py --since 3a1b2c4      # since a commit
    python3 scripts/progress.py --since 2026-10-27   # since a date (UTC)
    python3 scripts/progress.py --since 12h          # since 12 hours ago (or 3d)
    python3 scripts/progress.py                      # since 24 hours ago

Needs only git (and gh, if present, to list open pull requests).
"""
import argparse
import json
import re
import signal
import subprocess
import sys

BRANCH = "origin/main"
ROW = re.compile(r"^\|\s*((?:R\d+\.\d+)|(?:B\d+))\s*\|")


def git(*args, check=True):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout if result.returncode == 0 else None


def rows(text):
    """Roadmap rows as {id: (task, status)}; the status is the last cell."""
    found = {}
    for line in (text or "").splitlines():
        match = ROW.match(line)
        if match:
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            found[match.group(1)] = (cells[1], cells[-1])
    return found


def kind(status):
    for word in ("Done", "In progress", "Waiting", "Open"):
        if status.startswith(word):
            return word
    return status


def short(task, width=90):
    task = task.replace("`", "")
    return task if len(task) <= width else task[: width - 1] + "…"


def resolve_since(since, login):
    if login:
        at = re.escape("@" + login)
        for line in (git("log", BRANCH, "--format=%H\t%an\t%cn") or "").splitlines():
            sha, author, committer = line.split("\t")
            if login.lower() in (author.lower(), committer.lower()):
                return sha, f"your last commit or merge as {login}"
            added = git("show", "--format=", "--unified=0", sha, "--", "ROADMAP.md", check=False) or ""
            if any(l.startswith("+") and re.search(at, l, re.I) for l in added.splitlines()):
                return sha, f"your last roadmap edit as @{login}"
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


def open_pulls():
    url = git("remote", "get-url", "origin", check=False) or ""
    match = re.search(r"github\.com[:/]([^/]+)/([^/.\s]+)", url)
    if not match:
        return None
    try:
        out = subprocess.run(["gh", "api", f"repos/{match.group(1)}/{match.group(2)}/pulls?state=open"],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    return [(p["number"], p["title"], p["head"]["ref"]) for p in json.loads(out.stdout)]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--since", help="commit, date (YYYY-MM-DD) or age (12h, 3d)")
    parser.add_argument("--login", help="GitHub login: report since that person's last commit or roadmap edit")
    args = parser.parse_args()

    git("fetch", "--quiet", "--depth=500", "origin", "main", check=False)
    since, label = resolve_since(args.since, args.login)
    head = git("rev-parse", BRANCH).strip()
    date = git("show", "-s", "--format=%cd", "--date=format:%Y-%m-%d %H:%M UTC", since).strip()
    print(f"Progress on main since {label} ({since[:7]}, {date}):\n")
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

    old = rows(git("show", f"{since}:ROADMAP.md", check=False))
    new = rows(git("show", f"{head}:ROADMAP.md"))
    changes = {"Done": [], "Claimed": [], "Released": [], "New": [], "Other": []}
    for row_id, (task, status) in new.items():
        before = old.get(row_id)
        if before is None:
            changes["New"].append(f"  {row_id} {short(task)} [{status}]")
        elif before[1] != status:
            now, was = kind(status), kind(before[1])
            if now == "Done":
                changes["Done"].append(f"  {row_id} {short(task)} ({status})")
            elif now == "In progress":
                changes["Claimed"].append(f"  {row_id} {short(task)}: {status[len('In progress: '):]}")
            elif now == "Open" and was == "In progress":
                changes["Released"].append(f"  {row_id} {short(task)}")
            else:
                changes["Other"].append(f"  {row_id} {short(task)}: {before[1]} -> {status}")
    if not old and new:
        changes = {"Done": [], "Claimed": [], "Released": [], "Other": [],
                   "New": [f"  ROADMAP.md was added, with {len(new)} rows (summary below)"]}
    titles = {"Done": "Roadmap rows done", "Claimed": "Roadmap rows claimed",
              "Released": "Roadmap rows released (open again)", "New": "New roadmap rows",
              "Other": "Other roadmap changes"}
    for key, lines in changes.items():
        if lines:
            print(f"{titles[key]}:")
            print("\n".join(lines))

    counts = {}
    for _, status in new.values():
        counts[kind(status)] = counts.get(kind(status), 0) + 1
    print("\nRoadmap now: " + ", ".join(f"{counts.get(k, 0)} {k.lower()}" for k in ("Open", "In progress", "Waiting", "Done")))
    busy = [f"  {row_id} {short(task, 60)}: {status[len('In progress: '):]}"
            for row_id, (task, status) in new.items() if kind(status) == "In progress"]
    if busy:
        print("In progress now (leave these and their files alone):")
        print("\n".join(busy))
    pulls = open_pulls()
    if pulls:
        print("Open pull requests:")
        for number, title, ref in pulls:
            print(f"  #{number} {title} ({ref})")


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # exit quietly when piped into head
    main()
