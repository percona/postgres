# Using OpenBao as a KMIP-Compatible Key Provider

`pg_tde` is compatible with OpenBao via the KMIP protocol. For a full setup guide, see [the OpenBao documentation here](https://openbao.org/docs/install/).

To see an example configuration and installation of OpenBao on Ubuntu 24.04 for `pg_tde`, see [Install OpenBao on Ubuntu](#install-openbao-on-ubuntu).

## Install OpenBao on Ubuntu

The following steps allow you to install the OpenBao solution on Ubuntu with Percona's Server for PostgreSQL 17.

### Prerequisites

You need to ensure you meet the following:

- OS: Ubuntu 24.04
- `pg_tde` and Percona Server for PostgreSQL 17 installed

### Step 1. Install OpenBao

- Start by installing the latest version of OpenBao, run:

    ```bash
    # as root
    wget https://github.com/openbao/openbao/releases/download/v2.2.1/bao_2.2.1_linux_amd64.deb 
    dpkg -i ./bao_2.2.1_linux_amd64.deb
    ```

    !!! note
        This guide uses OpenBao version 2.2.1. You can replace it with the latest version.

- You can check the version by running:

    ```bash
    bao --version
    ```

### Step 2. Basic setup and configuration for OpenBao

- Move the original OpenBao configuration and create a new one, run:

    ```bash
    cp /etc/openbao/openbao.hcl /etc/openbao/openbao.hcl_DEPRECATED
    ```

- Create a new configuration file:

    ```bash
    echo '
    ui = true

    storage "file" {
    path = "/opt/openbao/data"
    }

    listener "tcp" {
    address     = "0.0.0.0:8200"
    tls_disable = 1
    }
    ' > /etc/openbao/openbao.hcl
    ```

- Set the correct permissions:

    ```bash
    chown openbao:openbao /etc/openbao/openbao.hcl
    ```

### Step 3. Start OpenBao

- To start your configuration, run:

    ```bash
    sudo systemctl enable --now openbao
    ```

- Check OpenBao's status to see if it is running:

    ```bash
    systemctl status openbao
    ```

    You should see output similar to the following:

    <details>
            <summary>Example output (click to expand)</summary>

             ● openbao.service - "OpenBao - A tool for managing secrets"
             Loaded: loaded (/usr/lib/systemd/system/openbao.service)
             Active: active (running)
             Docs:   https://github.com/openbao/openbao/tree/main/website/content/docs
             ...
             CGroup: /system.slice/openbao.service
                └─1061 /usr/bin/bao server --config=/etc/openbao/openbao.hcl
    </details>

### Step 4. Initialize OpenBao

Once OpenBao is running, you must initialize the system. This generates the unseal key and the initial root token, which are required to manage the server.

- Set the `VAULT_ADDR` environment variable to point to your OpenBao listener:

    ```bash
    export VAULT_ADDR="http://127.0.0.1:8200"
    ```

- Run the initialization command. This will generate one unseal key and one root token, and save them to a file:

    ```bash
    bao operator init -key-shares=1 -key-threshold=1 | grep -E 'Unseal|Token' > bao.ini
    ```

    !!! warning
        Do **not** store `bao.ini` on a shared system or in source control. It contains sensitive credentials.

    This filters only the `Unseal Key` and `Initial Root Token` lines and saves them in `bao.ini`.

    Example output:

    ```bash
    Unseal Key 1: LQtOF4m5ZwUtw9awGWiRf5/UNOEb4TqgJk8aP2z/0uE=
    Initial Root Token: s.QKH11VesQVHLykL2fursdNjK
    ```

### Step 5. Unseal and Mount the KV Secrets Engine

After initializing OpenBao, unseal the instance and mount a KV (key-value) secrets engine under the path `percona/`. This is where keys for `pg_tde` will be stored.

- Load the keys:

    Read the `UNSEAL_KEY` and `VAULT_TOKEN` from the `bao.ini` file:

    ```bash
    UNSEAL_KEY=$(cat bao.ini | grep Unseal | cut -d ':' -f 2)
    TOKEN=$(cat bao.ini | grep Token | cut -d ':' -f 2)
    ```

    Set the required environment variables:

    ```bash
    export VAULT_ADDR="http://127.0.0.1:8200"
    export VAULT_TOKEN=$TOKEN
    ```

- Unseal the OpenBao server, run:

    ```bash
    bao operator unseal $UNSEAL_KEY
    ```

    Expected output:

    ```yaml
    Seal Type: shamir
    Initialized: true
    Sealed: false
    ...
    ```

- Enable the KV engine, run:

    ```bash
    bao secrets enable --path=percona --version=2 kv
    ```

    This creates a versioned KV store at `percona/`, where you can store and manage keys securely.

- Confirm mount status:

    List all enabled secrets engines:

    ```bash
    bao secrets list
    ```

    Expected output:

    ```python
    Path        Type     Description
    ----        ----     -----------
    percona/    kv       n/a
    ...
    ```

### Step 6. Configure Key Provider for pg_tde

Once OpenBao is unsealed and the Percona KV store is mounted, configure a database-level key provider and principal key for your instance.

- Set Vault token environment variable:

    Extract and export the Vault token from your `bao.ini` file:

    ```bash
    export VAULT_TOKEN=$(cat bao.ini | grep Token | cut -d ':' -f 2)
    ```

- Connect as the postgres user and configure the database:

    Create a new database using the `tde_template`, and set up the provider:

    ```bash
    su - postgres <<_eof_
    dropdb --if-exists db01
    createdb db01 --template=tde_template

    psql db01 <<_eof1_
    \set ON_ERROR_STOP on

    -- Add the Vault V2 provider
    SELECT * FROM pg_tde_add_database_key_provider_vault_v2 (
        'percona01',                    -- provider name
        '$VAULT_TOKEN',                -- Vault token
        'http://127.0.0.1:8200',       -- Vault address
        'percona',                     -- mount path in Vault
        NULL                           -- optional CA cert
    );

    -- Set the encryption key for this database
    SELECT * FROM pg_tde_set_key_using_database_key_provider (
        'key01',                       -- key name
        'percona01',                   -- provider name
        true                           -- ensure key is unique
    );

    -- (Optional) Verify setup
    SELECT * FROM pg_tde_list_all_database_key_providers();
    SELECT * FROM pg_tde_key_info();
    _eof1_
    _eof_
    ```

For more information on related functions, see the link below:

[Percona pg_tde Function Reference](../functions.md){.md-button}

## Next steps

[Global Principal Key Configuration :material-arrow-right:](set-principal-key.md){.md-button}
