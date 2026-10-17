# Working together with Git

The shared repository is [taymor3/ASIC-bcjrformer](https://github.com/taymor3/ASIC-bcjrformer).
Use the project root as the working directory. The original maintainer workspace
now uses `Project 2` itself as its checkout; `publish/ASIC-bcjrformer` is an
excluded historical publication copy and must not be edited as the active project.

## Start a work session

Check the current branch and unfinished edits, then update a clean checkout:

```sh
git status --short
git branch --show-current
git pull --ff-only
```

If there are unfinished edits or Git refuses the fast-forward, preserve the
work and inspect the difference before continuing. Do not use a hard reset or
force push to resolve a disagreement between local and remote work.

## Share a completed change

Review the diff and run the relevant checks from the verification guide. Stage
specific changed paths, commit, and push:

```sh
git diff
git add path/to/changed-file
git diff --cached
git commit -m "Describe the change"
git push
```

Replace the example path with the actual changed files. A commit records a
local version; pushing shares those commits on GitHub. If someone updated the
same branch first, fetch and integrate their work before retrying. Never force
push over their commits. A successful push should be followed by checking the
GitHub Actions result; those structural/numerical checks are not full model
validation.

## Working simultaneously

Use a separate branch for each change so two people do not compete to update
main. For example, from a clean checkout:

```sh
git switch main
git pull --ff-only
git switch -c codex/embedding-review
# Edit, review, check, and commit the focused change.
git push -u origin codex/embedding-review
```

Open a pull request into main and have the other collaborator review it before
merging. Review and merge are explicit human decisions. Delete or reuse branches
only after confirming their work has been integrated. New branches created by
Codex use the `codex/` prefix; human collaborators may choose their own names.

## Adding Haiel later

When his GitHub username is available, the repository owner can open
**Settings > Collaborators > Add people**, select the correct account, and grant
write access. He must accept the invitation before he can push. Public visibility
alone does not grant write access or waive LICENSE.md.

After accepting, Haiel can create his own working copy:

```sh
git clone https://github.com/taymor3/ASIC-bcjrformer.git
cd ASIC-bcjrformer
```

Each person authenticates with their own GitHub account. Never share a password
or token. Native Git authentication and the Codex GitHub connector are separate;
the connected plugin can publish authorized changes even if terminal push
authentication needs refreshing.

## Local-only material

The original upstream model checkout, reference papers, local tools, generated
results, and publication backups remain local and excluded from version control.
The migration preserved replaced workspace files under
`publish/root-checkout-backup-2026-10-17`; its `migration.json` lists them.
New clones will contain the project-owned public files, not these local extras.
