{
  inventory,
  hostName ? "ember",
}:
let
  host = inventory.hosts.${hostName};
  storage = host.storage;
  storageBound =
    storage.targetDisk != null && storage.layoutModule != null && storage.layoutConfirmed;
in
{
  target = hostName;
  storageBound = storageBound;
  installable = storageBound;
  reason =
    if storageBound then
      "storage target and layout are bound and confirmed"
    else
      "target disk and layout are not selected/confirmed; installing or activating this configuration is intentionally unavailable";
}
