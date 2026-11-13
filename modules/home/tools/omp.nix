{
  config,
  lib,
  pkgs,
  ...
}:
{
  # OMP owns writable settings/auth/session files. Its binary belongs to the
  # independent software profile; never symlink its credentials into the store.
  home.activation.emberOmpState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.omp" "$HOME/.omp/agent"
  '';
}
