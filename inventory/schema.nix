{
  lib,
  inventory,
}:
let
  inherit (builtins)
    attrNames
    elem
    isAttrs
    isList
    isPath
    isString
    length
    match
    pathExists
    substring
    ;

  fail = message: throw "ember inventory: ${message}";

  require = condition: message: if condition then true else fail message;

  hosts = inventory.hosts or { };
  users = inventory.users or { };

  checkStorage =
    hostName: storage:
    require (isAttrs storage) "hosts.${hostName}.storage must be an attrset"
    && require (storage ? targetDisk) "hosts.${hostName}.storage.targetDisk is missing"
    && require (storage ? layoutModule) "hosts.${hostName}.storage.layoutModule is missing"
    && require (storage ? layoutConfirmed) "hosts.${hostName}.storage.layoutConfirmed is missing"
    && (
      if
        storage.targetDisk == null && storage.layoutModule == null && storage.layoutConfirmed == false
      then
        true
      else if
        isString storage.targetDisk
        && storage.targetDisk != ""
        && (isPath storage.layoutModule || isString storage.layoutModule)
        && pathExists storage.layoutModule
        && storage.layoutConfirmed == true
      then
        true
      else
        fail "hosts.${hostName}.storage must be either targetDisk=null, layoutModule=null, layoutConfirmed=false or a fully confirmed binding"
    );

  checkUser =
    userName: user:
    require (isAttrs user) "users.${userName} must be an attrset"
    && require (
      user.name or userName == userName
    ) "users.${userName}.name must equal the attribute name"
    && require (user ? uid) "users.${userName}.uid is missing"
    && require (builtins.isInt user.uid) "users.${userName}.uid must be an integer"
    && require (user.uid >= 1000 && user.uid <= 60000) "users.${userName}.uid must be in 1000..60000"
    && require (isString (user.home or null)) "users.${userName}.home must be a string"
    && require (lib.hasPrefix "/" user.home) "users.${userName}.home must be absolute"
    && require (elem (user.loginShell or null) [ "zsh" ]) "users.${userName}.loginShell must be zsh"
    && require (isList (user.extraGroups or null)) "users.${userName}.extraGroups must be a list"
    && require (
      isString (user.initialHashedPassword or null) && substring 0 3 user.initialHashedPassword == "$6$"
    ) "users.${userName}.initialHashedPassword must be a SHA-512 crypt hash"
    && require (
      (user.persistenceModule or null) != null && pathExists user.persistenceModule
    ) "users.${userName}.persistenceModule must point to an existing file"
    && require (
      (user.homeModule or null) != null && pathExists user.homeModule
    ) "users.${userName}.homeModule must point to an existing file"
    && require (
      isString (user.homeStateVersion or null)
      && match "[0-9]{2}\\.[0-9]{2}" user.homeStateVersion != null
    ) "users.${userName}.homeStateVersion must be a literal YY.MM string";

  checkHost =
    hostName: host:
    require (isAttrs host) "hosts.${hostName} must be an attrset"
    && require (host.system or null == "x86_64-linux") "hosts.${hostName}.system must be x86_64-linux"
    && require (isString (host.hostName or null)) "hosts.${hostName}.hostName must be a string"
    && require (
      isString (host.stateVersion or null) && match "[0-9]{2}\\.[0-9]{2}" host.stateVersion != null
    ) "hosts.${hostName}.stateVersion must be a literal YY.MM string"
    && require (
      (host.hostModule or null) != null && pathExists host.hostModule
    ) "hosts.${hostName}.hostModule must point to an existing file or directory"
    && require (isList (
      host.hardwareModules or null
    )) "hosts.${hostName}.hardwareModules must be a list"
    && require (host.hardwareModules != [ ]) "hosts.${hostName}.hardwareModules must not be empty"
    && require (builtins.all (
      module: (isPath module || isString module) && pathExists module
    ) host.hardwareModules) "hosts.${hostName}.hardwareModules must point to existing files"
    && require (isList (host.users or null)) "hosts.${hostName}.users must be a list"
    && require (host.users != [ ]) "hosts.${hostName}.users must not be empty"
    && require (builtins.all (
      userName: users ? ${userName}
    ) host.users) "hosts.${hostName}.users references a user missing from users"
    && require (
      length (lib.unique (map (userName: users.${userName}.uid) host.users)) == length host.users
    ) "hosts.${hostName}.users contains duplicate UIDs"
    && checkStorage hostName host.storage;

  userChecks = builtins.all (userName: checkUser userName users.${userName}) (attrNames users);
  hostChecks = builtins.all (hostName: checkHost hostName hosts.${hostName}) (attrNames hosts);
  allUids = map (userName: users.${userName}.uid) (attrNames users);
  allHostNames = map (hostName: hosts.${hostName}.hostName) (attrNames hosts);
in
if
  require (isAttrs inventory) "inventory must be an attrset"
  && require (hosts != { }) "at least one host is required"
  && require (users != { }) "at least one user is required"
  && userChecks
  && hostChecks
  && require (
    length (lib.unique allUids) == length allUids
  ) "user UIDs must be unique across inventory"
  && require (
    length (lib.unique allHostNames) == length allHostNames
  ) "hostnames must be unique across inventory"
then
  inventory
else
  fail "inventory validation failed"
