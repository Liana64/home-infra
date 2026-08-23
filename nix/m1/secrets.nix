{
  inputs,
  config,
  ...
}: {
  sops = {
    defaultSopsFile = "${inputs.secrets}/m1.yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [];
    gnupg.sshKeyPaths = [];
    secrets."users/liana/password".neededForUsers = true;
    secrets."users/maxine/password".neededForUsers = true;
  };

  users = {
    mutableUsers = false;
    users.liana.hashedPasswordFile = config.sops.secrets."users/liana/password".path;
    users.maxine.hashedPasswordFile = config.sops.secrets."users/maxine/password".path;
  };
}
