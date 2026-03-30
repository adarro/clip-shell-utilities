<!-- markdownlint-disable-file MD033 -->

# Git Tool Support

gittools.just is a conditional import that adds convenience functions for some git functions

## Git Submodules

### Existence check

requires Path

We need to be able to check if a given submodule exists

### Add Submodule

Add a submodule or warn if it already exists

requires:

- url - repo url

optional:

- path - overrides default folder name

### Remove Submodule

Removes a Submodule
This is a much more involved process

requires:

- path

#### Concerns

we should provide some sort of check-point / save to provide some fall-back path

#### Steps

Create checkpoint:
: provides a restore point

- create a pre-commit snapshot
- stash any uncommitted user data

~~De-init Module~~ (Deprecated -- see Improved RM Command)
: Removes entry from .git/config

```shell
git submodule deinit -f --$path
```

~~Remove Submodule Directory~~ (Deprecated -- see Improved RM Command)
: physically remove directory

```shell
rm -rf $path
```

Updated Removal command
: Newer git command removes physical path and local .gitmodules entry

```bash
git rm -f $path
```

~~Remove Entry from .gitmodules~~ (Deprecated -- see Improved RM Command)
: Find and remove the entire code block related to the submodule

<figure>

```ini
[submodule "$path"]
path = some/path
url = repo/url

```

<figcaption>typical config entry</figcaption>
</figure>

Remove entry from `.git/config`
: remove the entire block related to the submodule
: config file may be under `<root>/.git/config` or `<root>/.git/modules/<sub-module>/config`

<figure>

```bash
config_path=$(git rev-parse --git-dir)
config_file="${config_path}/config"
# printf "Git Config Directory: %s\n" "${config_path}"
# printf "Git Config File: %s\n" "${config_file}"
```

<figcaption>example bash script</figcaption>
</figure>

<figure>

```ini
[submodule "$path"]
path = some/path
url = repo/url

```

<figcaption>typical config entry at above location</figcaption>
</figure>

Commit (Success)
: commit changes if successful

```shell
git add .gitmodules
git add -u
git commit -m A_NICE_BETTER_COMMIT
```

Unstack (Success)
: restore stashed work if successful

Rollback (failure)
: restore for pre-commit snapshot

Clear Cache (Success)
: purge any lingering references
: may no longer have any effect

```shell
git rm -r --cached $path
```
