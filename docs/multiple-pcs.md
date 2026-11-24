# Working across multiple computers

## Run the network on four Macs

Clone the repository once on each Mac. Each clone contains the same project, but each machine runs only its assigned services from phase2-plan.md. Configure real current LAN IPs in machine-local copies of the examples. Start backends first, then edge, then verify DNS and trusted HTTPS. Keep separate terminals for service logs and tests. One laptop changing Wi-Fi or sleeping can break its services.

## Use the same Git identity on your own PCs

In each of YOUR clones:

```sh
git config user.name Mystic-commits
git config user.email yugjohri520@gmail.com
```

This email was returned by the connected Mystic-commits profile. Confirm it remains verified on GitHub for account attribution. Teammates should use their own identities for their work. Git identity does not authenticate you: sign in separately on each PC using its own SSH key or credential manager.

## Synchronize later through GitHub

This review did not push. For normal work after changes are published intentionally:

1. Before editing, run `git status`, then `git fetch origin`. With a clean working tree on a tracking branch, run `git pull --ff-only`.
2. Use a task branch, for example `git switch -c codex/dns-backup`.
3. Make a coherent change, review `git diff`, stage specific files and commit with a descriptive message.
4. When you decide to publish, push the task branch and review/merge it. On the next PC, fetch and switch to that branch before continuing.
5. If histories diverge, inspect and merge or rebase your own unpublished changes; do not force-push as a routine synchronization method.

A local commit on PC A is not automatically available on PC B. GitHub synchronizes only commits you explicitly push.

## Transfer without pushing

On the reviewed clone:

```sh
git bundle create CN_Project_TeamBabyShark.bundle --all
```

Copy the bundle using AirDrop, USB or an authenticated LAN transfer. On a new PC:

```sh
git clone -b codex/phase2 /path/to/CN_Project_TeamBabyShark.bundle CN_Project_TeamBabyShark
```

The bundle's source becomes origin. If you later want the GitHub remote, intentionally change it:

```sh
git remote set-url origin https://github.com/Mystic-commits/CN_Project_TeamBabyShark.git
```

For an existing clone, first commit or stash local edits, then fetch the bundle into a separate review branch:

```sh
git fetch /path/to/CN_Project_TeamBabyShark.bundle refs/heads/codex/phase2:refs/heads/review/phase2-import
```

Inspect that branch before switching or merging. The cleaned branch rewrites the two original commit IDs, so do not casually merge it with old main or pull old main into it. Publishing that cleaned history would need a deliberate coordinated history replacement; no such remote action has been performed.

## Local history cleanup in this review

The original main and backup/original-history preserve the original two commits. Only codex/phase2 has normalized author/committer identity and the Cursor co-author trailer removed. Original timestamps and file trees were preserved. New documentation commits use the current time. Removing a trailer locally does not change GitHub's contributor display until remote history is deliberately changed.

Keep node_modules, Python environments, logs, local machine settings and TLS private keys out of Git. Install dependencies independently on each PC. Do not synchronize an active .git directory through a live cloud-sync folder.

Reference: https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project
