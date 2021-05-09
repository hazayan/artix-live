# alpm-hooks

' arch alpmm-hooks man

### SYNOPSIS

```
[Trigger] (Required, Repeatable)
Operation = Install|Upgrade|Remove (Required, Repeatable)
Type = Path|Package (Required)
Target = <Path|PkgName> (Required, Repeatable)

[Action] (Required)
Description = ... (Optional)
When = PreTransaction|PostTransaction (Required)
Exec = <Command> (Required)
Depends = <PkgName> (Optional)
AbortOnFail (Optional, PreTransaction only)
NeedsTargets (Optional)
```

### DESCRIPTION

libalpm provides the ability to specify hooks to run before or after transactions based on the packages and/or files being modified. Hooks consist of a single [Action] section describing the action to be run and one or more [Trigger] section describing which transactions it should be run for.

Hooks are read from files located in the system hook directory /usr/local/share/libalpm/hooks, and additional custom directories specified in pacman.conf(5) (the default is /usr/local/etc/pacman.d/hooks). The file names are required to have the suffix ".hook". Hooks are run in alphabetical order of their file name, where the ordering ignores the suffix.


### TRIGGERS

Hooks must contain at least one [Trigger] section that determines which transactions will cause the hook to run. If multiple trigger sections are defined the hook will run if the transaction matches any of the triggers.

> #### Operation = Install|Upgrade|Remove

* Select the type of operation to match targets against. May be specified multiple times. Installations are considered an upgrade if the package or file is already present on the system regardless of whether the new package version is actually greater than the currently installed version. For Path triggers, this is true even if the file changes ownership from one package to another. Required.

> #### Type = Path|Package

* Select whether targets are matched against transaction packages or files. See CAVEATS for special notes regarding Path triggers. File is a deprecated alias for Path and will be removed in a future release. Required.

> #### Target = <path|package>

* The path or package name to match against the active transaction. Paths refer to the files in the package archive; the installation root should not be included in the path. Shell-style glob patterns are allowed. It is possible to invert matches by prepending a target with an exclamation mark. May be specified multiple times. Required.


### ACTIONS

> #### Description = …

* An optional description that describes the action being taken by the hook for use in front-end output.

> #### Exec = [command]

* Command to run. Command arguments are split on whitespace. Values containing whitespace should be enclosed in quotes. Required.

> #### When = PreTransaction|PostTransaction

* When to run the hook. Required.

> #### Depends = [package]

* Packages that must be installed for the hook to run. May be specified multiple times.

> #### AbortOnFail

* Causes the transaction to be aborted if the hook exits non-zero. Only applies to PreTransaction hooks.

> #### NeedsTargets

* Causes the list of matched trigger targets to be passed to the running hook on stdin.

https://archlinux.org/pacman/alpm-hooks.5.html