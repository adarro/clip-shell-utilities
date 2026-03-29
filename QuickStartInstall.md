## install_sub.sh

## Overview

i'd like to create a bash install script such that can "curl | sh"  the script should be kept as readable as possible so the user can better determine whether to use it.

## Install

By install, i mean it is intended to be called from the root of an existing git repo.

when executed it should:

* check if it's in a git repository
* if its in the root
* call git submodule add
* check for existing justfile
* if none exists, create one and add clipp as a mod with path (see New File)
* if one does exist, then we create a import file (see Import).
* upon success print a message either about including the file or running the new file.

### New File (Module)

```rust
# ${rootdir}/justfile
# this should be some comment like
# added by ${github repo url}
mod clipp './clip-shell-utilities'

@firstrun:
  @just clipp::setup
  @just clipp::check

```

### Import

They have an existing justfile, and we don't want to do anything intrusive or fancy
in a basic shell script (at this time) so we create a file 'clippstub.just' with something similar to this snippet.

``` rust
# ${rootdir}/clippstub.just

# To use this as a module, copy the line below into your justfile
mod clipp './clip-shell-utilities'
# if you use the above method:
# * recipies must be referenced by 'clipp::recipe'
# * will not by default be listed with --list
# * this file will be redundant and obsolete
#   (so you can then safely delete it.)

# Alternatively

# To include (import) the recipies from clip-shell-utilities
# paste the line below (uncommented) in your justfile 
# import 'clippstub.just'

# all recipes will be included as if they were in your main file if you use this option.

```

This may evolve over time to be more flexible or comprehensive.
These instructions should be updated to reflect the results.