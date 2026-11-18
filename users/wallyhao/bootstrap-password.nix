# The real initial account hash is local-only and lives in the git-ignored
# `bootstrap-password.local.nix`. The fallback is the hash of a discarded
# random password: it keeps evaluation and CI buildable without exposing a
# usable login credential. Create the local file before installing:
#
#   printf '"%s"\n' "$(mkpasswd -m sha-512)" > users/wallyhao/bootstrap-password.local.nix
#
if builtins.pathExists ./bootstrap-password.local.nix then
  import ./bootstrap-password.local.nix
else
  "$6$1pZS.z6UkPsJo7AM$2aZlKU6WFuWOUq8yA1oLoGsWglANMIc515rRHqwU.avXDepl7Dm4Qv0Tt/1Qo1HwjTOVgmON4J/WXNy0ylggI."
