# How does TDE help?

## Benefits for organizations

* Data safety: Prevents unauthorized access to stored data, even if backup files or storage devices are stolen or leaked.
* Supports regulatory alignment: Implements encryption-at-rest, a common requirement in standards such as HIPAA, PCI DSS, and ISO/IEC 27001.

## Benefits for DBAs and engineers

* Granular control: Encrypt specific tables or databases instead of the entire system, reducing performance overhead.
* Operational simplicity: Works transparently without requiring major application changes.
* Defense in depth: Adds another layer of protection to existing controls like TLS (encryption in transit), access control, and role-based permissions.

When combined with external Key Management Systems (KMS), TDE enables centralized control, auditing, and rotation of encryption keys—critical for secure production environments.

!!! note "Compliance Disclaimer"
    Percona TDE includes encryption features that align with common security best practices.  
    However, using TDE alone does not guarantee compliance with any specific regulatory standard (e.g., HIPAA, PCI DSS, SOC 2, or ISO/IEC 27001).  
    Organizations are responsible for evaluating the overall security posture and ensuring that all necessary controls and validations are in place to meet regulatory requirements.

!!! admonition "See also"

    Percona Blog: [Transparent Data Encryption (TDE)](https://www.percona.com/blog/transparent-data-encryption-tde/)
    
[How does TDE work?](how-does-tde-work.md){.md-button}
