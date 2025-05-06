# TDE Benefits

## Benefits for organizations

* Data safety: Prevents unauthorized access to stored data, even if backup files or storage devices are stolen or leaked.
* Supports regulatory alignment: Enables encryption-at-rest to assist with meeting compliance expectations.

## Benefits for DBAs and engineers

* Granular control: Encrypt specific tables or databases instead of the entire system, reducing performance overhead.
* Operational simplicity: Works transparently without requiring major application changes.
* Defense in depth: Adds another layer of protection to existing controls like TLS (encryption in transit), access control, and role-based permissions.

When combined with external Key Management Systems (KMS), TDE enables centralized control, auditing, and rotation of encryption keys—critical for secure production environments.

!!! note "Compliance Disclaimer"  
    Percona Transparent Data Encryption (TDE) is only one part of a broader compliance strategy.  Compliance depends on security controls, policies, and practices within your organization or environment.

!!! admonition "See also"

    Percona Blog: [Transparent Data Encryption (TDE)](https://www.percona.com/blog/transparent-data-encryption-tde/)
    
[How TDE works](how-does-tde-work.md){.md-button}
