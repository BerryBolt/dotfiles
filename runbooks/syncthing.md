# Syncthing workstation recovery

The setup installs Syncthing and enables the user service `syncthing-workstation.service`. It restores the workstation identity and configuration before starting the service. The peer is independently managed and is not installed by this repository.

In the configured vault, `Syncthing - Credential File` is a Document containing JSON with `version` set to `1`, `cert.pem`, `key.pem`, and `config.xml`. The XML stores an empty `gui/apikey` element and uses `${HOME}` for account-relative paths. `Syncthing - API key` is an API Credential whose `credential` field supplies the API key. No web login exists for this local service.

The restore command reads both items in scoped child processes. It rejects an existing identity that differs from the document. It stops the workstation service before changing its files, writes private files, creates configured folders, and enables the service. Unchanged configuration does not restart the service. Databases and synchronized contents stay outside Git and the recovery document.

Before restoring this identity on another machine, stop the old workstation instance. Keep the peer available and provide network access to the addresses in the saved configuration. The platform owns that connectivity. Restoring credentials does not bypass network isolation.

To change settings, update the recovery document and reapply. To rotate the API key, update its API Credential and reapply. Verify API access and synchronization before reporting success. Never print the document or API value in logs.
