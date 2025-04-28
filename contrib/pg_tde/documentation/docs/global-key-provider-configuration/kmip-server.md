# Set up with KMIP server

Set up a global key provider

Make sure you have obtained the root certificate for the KMIP server and the keypair for the client. The client key needs permissions to create / read keys on the server. Find the [configuration guidelines for the HashiCorp Vault Enterprise KMIP Secrets Engine](https://developer.hashicorp.com/vault/tutorials/enterprise/kmip-engine).

For testing purposes, you can use the PyKMIP server which enables you to set up required certificates. To use a real KMIP server, make sure to obtain the valid certificates issued by the key management appliance.

```sql
SELECT pg_tde_add_global_key_provider_kmip('provider-name','kmip-IP', 5696, '/path_to/server_certificate.pem', '/path_to/client_key.pem');
```

where:

* `provider-name` is the name of the provider. You can specify any name, it's for you to identify the provider.
* `kmip-IP` is the IP address of a domain name of the KMIP server
* `port` is the port to communicate with the KMIP server. Typically used port is 5696.
* `server-certificate` is the path to the certificate file for the KMIP server.
* `client key` is the path to the client key.

<i warning>:material-information: Warning:</i> Note that pg_tde_add_global_key_provider_kmip currently accepts only a combined client key + client certificate for the last parameter of this function named as `client key`.

<i warning>:material-information: Warning:</i> This example is for testing purposes only:

```sql
SELECT pg_tde_add_global_key_provider_kmip('kmip','127.0.0.1', 5696, '/tmp/server_certificate.pem', '/tmp/client_key_jane_doe.pem');
```
