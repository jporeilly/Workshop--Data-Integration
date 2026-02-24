# Scenario 6: Security Implementation (SSL/SASL)

**Business Use Case**: Secure Kafka communication in enterprise environments using SSL encryption, SASL authentication, and encrypted credentials within PDI transformations.

**Difficulty**: Advanced | **Duration**: Reference Guide (no hands-on build)

## Learning Objectives

- Understand the SSL encryption properties required in PDI's Kafka Consumer and Producer Options tabs
- Configure SASL/PLAIN authentication for username/password-based access
- Configure SASL/SCRAM authentication for stronger credential hashing
- Configure Kerberos (GSSAPI) authentication for enterprise single sign-on environments
- Use PDI's `Encr` tool to encrypt sensitive passwords
- Apply the `Encrypted` prefix format in Options tab values
- Generate self-signed certificates for development/testing with `keytool`
- Follow security best practices for credential management and access control

## Prerequisites

Before referencing this scenario:

1. Familiarity with PDI Kafka Consumer and Producer configuration (complete at least [Scenario 1](scenario-1-user-activity.md))
2. Understanding of the Options tab in both Kafka Consumer and Kafka Producer steps
3. Access to a Kafka cluster configured with SSL/SASL (not the workshop Docker environment)
4. PDI (Spoon) is open with Kafka EE plugin installed

> **Note**: The workshop Docker environment does **not** have SSL or SASL configured. This scenario is a **reference guide** for configuring security in production or pre-production Kafka clusters. The configuration patterns shown here apply to the Options tab of both the Kafka Consumer and Kafka Producer steps.

## Architecture

```
PDI Client (Spoon / Kitchen / Pan)
    |
    | SSL/TLS encrypted connection
    | + SASL authentication (optional)
    |
    v
Kafka Broker(s) (SSL listener on port 9093+)
    |
    | Inter-broker SSL (optional)
    |
    v
ZooKeeper (separate authentication)
```

**Security layers**:

| Layer | Protocol | Purpose |
|-------|----------|---------|
| Encryption | SSL/TLS | Encrypt data in transit between PDI and Kafka brokers |
| Authentication | SASL/PLAIN | Username/password authentication (simple) |
| Authentication | SASL/SCRAM | Username/password with salted challenge-response (stronger) |
| Authentication | SASL/GSSAPI | Kerberos ticket-based authentication (enterprise SSO) |
| Authorization | Kafka ACLs | Control which users can read/write which topics (broker-side) |

---

## Security Configuration Reference

All security properties below are entered in the **Options tab** of the PDI Kafka Consumer step or the Kafka Producer step. Click **+** to add each property as a key-value pair.

> **Important**: The same properties apply to both the Kafka Consumer and the Kafka Producer. When securing your pipeline, configure the Options tab in **both** the parent transformation's Kafka Consumer step and any Kafka Producer steps.

---

### Configuration 1: SSL Encryption (No Authentication)

SSL encryption without SASL provides encryption in transit but does not authenticate the client by username/password. The broker validates the client's certificate if mutual TLS (mTLS) is enabled.

#### Options Tab Properties

| Property | Value | Notes |
|----------|-------|-------|
| `security.protocol` | `SSL` | Enables SSL/TLS encryption |
| `ssl.truststore.location` | `/path/to/kafka.client.truststore.jks` | JKS file containing the broker's CA certificate |
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Truststore password (use PDI `Encr` tool) |
| `ssl.keystore.location` | `/path/to/kafka.client.keystore.jks` | JKS file containing the client's private key and certificate |
| `ssl.keystore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Keystore password (use PDI `Encr` tool) |
| `ssl.key.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Private key password (use PDI `Encr` tool) |

> **Truststore vs. Keystore**: The **truststore** holds certificates you trust (the broker's CA). The **keystore** holds your own identity (client certificate + private key). If the broker does not require client certificate authentication (one-way SSL), you only need the truststore. If the broker requires mutual TLS (two-way SSL), you need both.

#### When to Use

- You need encryption in transit but the broker does not use SASL for authentication
- The broker is configured with `ssl.client.auth=required` (mTLS) or `ssl.client.auth=none` (one-way SSL)
- Development and testing environments with self-signed certificates

---

### Configuration 2: SASL/PLAIN over SSL

SASL/PLAIN transmits username and password in cleartext within the SASL handshake, so it **must** be combined with SSL encryption to protect credentials on the wire.

#### Options Tab Properties

| Property | Value | Notes |
|----------|-------|-------|
| `security.protocol` | `SASL_SSL` | Enables both SASL authentication and SSL encryption |
| `sasl.mechanism` | `PLAIN` | PLAIN mechanism (username/password in cleartext within SASL) |
| `ssl.truststore.location` | `/path/to/kafka.client.truststore.jks` | Broker CA certificate truststore |
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Truststore password |
| `sasl.jaas.config` | *(see below)* | JAAS configuration inline |

**JAAS config value** (entered as a single line in the Options tab value field):

```
org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka-user" password="Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4";
```

> **Formatting**: The entire JAAS config must be on a **single line** in the Options tab value field. The trailing semicolon (`;`) is required. Do not add line breaks.

> **Plain text vs. Encrypted password in JAAS config**: PDI will decrypt values that start with `Encrypted` before passing them to the Kafka client library. You can use either the encrypted form or plaintext, but encrypted is strongly recommended.

#### When to Use

- Managed Kafka services (Confluent Cloud, Amazon MSK with SASL) that use username/password authentication
- Environments where SCRAM or Kerberos infrastructure is not available
- Always pair with SSL (`SASL_SSL`, never `SASL_PLAINTEXT`) to protect credentials

---

### Configuration 3: SASL/SCRAM over SSL

SASL/SCRAM (Salted Challenge Response Authentication Mechanism) provides stronger password-based authentication than PLAIN. The password is never sent in cleartext, even within the SASL handshake. SCRAM-SHA-256 and SCRAM-SHA-512 are the two supported variants.

#### Options Tab Properties

| Property | Value | Notes |
|----------|-------|-------|
| `security.protocol` | `SASL_SSL` | Enables both SASL authentication and SSL encryption |
| `sasl.mechanism` | `SCRAM-SHA-256` | Or `SCRAM-SHA-512` for stronger hashing |
| `ssl.truststore.location` | `/path/to/kafka.client.truststore.jks` | Broker CA certificate truststore |
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Truststore password |
| `sasl.jaas.config` | *(see below)* | JAAS configuration inline |

**JAAS config value** (entered as a single line in the Options tab value field):

```
org.apache.kafka.common.security.scram.ScramLoginModule required username="kafka-user" password="Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4";
```

> **SCRAM-SHA-256 vs. SCRAM-SHA-512**: Both are salted challenge-response mechanisms. SHA-512 provides a larger hash but both are considered secure. Use whichever your Kafka broker is configured to support. Check the broker's `sasl.enabled.mechanisms` setting.

#### When to Use

- Enterprise environments that require stronger password-based authentication than PLAIN
- When Kerberos infrastructure is not available but you need better security than PLAIN
- On-premises Kafka clusters with SCRAM users created via `kafka-configs.sh --alter --add-config`

---

### Configuration 4: Kerberos (SASL/GSSAPI)

Kerberos authentication uses tickets issued by a Key Distribution Center (KDC) rather than passwords. This is common in Hadoop/enterprise environments where Kerberos is already deployed for HDFS, Hive, and other services.

#### Options Tab Properties

| Property | Value | Notes |
|----------|-------|-------|
| `security.protocol` | `SASL_SSL` | Use `SASL_PLAINTEXT` only if SSL is not available |
| `sasl.mechanism` | `GSSAPI` | Kerberos authentication mechanism |
| `sasl.kerberos.service.name` | `kafka` | The Kerberos principal name of the Kafka broker service |
| `ssl.truststore.location` | `/path/to/kafka.client.truststore.jks` | Required if using `SASL_SSL` |
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Required if using `SASL_SSL` |
| `sasl.jaas.config` | *(see below)* | JAAS configuration inline |

**JAAS config value** (entered as a single line in the Options tab value field):

```
com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true keyTab="/path/to/kafka-client.keytab" principal="pdi-service@EXAMPLE.COM" storeKey=true;
```

> **Keytab vs. Ticket Cache**: Using `useKeyTab=true` with a keytab file is recommended for automated/service accounts (like PDI running on a server). For interactive use, you can set `useTicketCache=true` instead, which uses the current user's Kerberos ticket obtained via `kinit`.

> **Service name**: The `sasl.kerberos.service.name` must match the primary component of the Kafka broker's Kerberos principal. If the broker runs as `kafka/broker-host@REALM`, the service name is `kafka`.

#### Additional JVM Requirements

Kerberos requires a `krb5.conf` file on the PDI client machine. Set the JVM system property in Spoon's startup script:

```bash
# In spoon.sh or set-pentaho-env.sh:
export JAVA_OPTS="$JAVA_OPTS -Djava.security.krb5.conf=/etc/krb5.conf"
```

On Windows, add to `spoon.bat`:
```batch
set JAVA_OPTS=%JAVA_OPTS% -Djava.security.krb5.conf=C:\ProgramData\MIT\Kerberos5\krb5.ini
```

#### When to Use

- Hadoop-integrated environments (Cloudera, Hortonworks/CDP) where Kerberos is the standard authentication mechanism
- Enterprise environments with centralized identity management via Active Directory/KDC
- When you need single sign-on across multiple services (HDFS, Hive, Kafka, etc.)

---

## PDI Password Encryption

PDI provides the `Encr` command-line tool to encrypt passwords so they are not stored in plaintext in transformation files or Options tab values.

### Using the Encr Tool

The `Encr` tool is located in the PDI installation directory.

#### Linux / macOS

```bash
cd /path/to/data-integration

# Encrypt a password
./encr.sh -kettle "MySecretPassword"
```

Output:
```
Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4
```

#### Windows

```cmd
cd C:\path\to\data-integration

REM Encrypt a password
encr.bat -kettle "MySecretPassword"
```

Output:
```
Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4
```

### Using Encrypted Passwords in the Options Tab

1. Run the `Encr` tool on your password to get the encrypted value
2. In the Kafka Consumer (or Producer) Options tab, enter the **full string** including the `Encrypted` prefix:

| Property | Value |
|----------|-------|
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` |
| `ssl.keystore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` |
| `ssl.key.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` |

> **Important**: Include the word `Encrypted` followed by a space, then the hex string. PDI detects the `Encrypted` prefix and decrypts the value at runtime before passing it to the Kafka client library.

> **JAAS config passwords**: The `Encrypted` prefix also works inside `sasl.jaas.config` values. PDI processes the entire value and decrypts any `Encrypted` tokens it finds.

### Encryption Scope

The `Encr` tool uses a static key built into PDI. This means:
- Encrypted values are portable across PDI installations of the same version
- This is **obfuscation**, not strong encryption -- it prevents casual reading of passwords but is not a substitute for file-system access controls
- For production environments, combine with file-system permissions, secrets management (HashiCorp Vault, AWS Secrets Manager), and PDI variables loaded from secured property files

---

## Certificate Generation (Self-Signed)

For development and testing, you can generate self-signed certificates using Java's `keytool` utility. Production environments should use certificates signed by a trusted Certificate Authority (CA).

### Step 1: Generate a Certificate Authority (CA)

```bash
# Generate a CA key pair
openssl req -new -x509 -keyout ca-key.pem -out ca-cert.pem -days 365 \
  -subj "/CN=KafkaCA" -passout pass:ca-password
```

### Step 2: Generate Broker Keystore and Certificate

```bash
# Generate broker keystore with a key pair
keytool -genkeypair -alias broker -keyalg RSA -keysize 2048 \
  -keystore kafka.broker.keystore.jks -validity 365 \
  -storepass broker-ks-password -keypass broker-key-password \
  -dname "CN=kafka-broker,OU=Kafka,O=Workshop,L=City,ST=State,C=US"

# Create a certificate signing request (CSR)
keytool -certreq -alias broker -keystore kafka.broker.keystore.jks \
  -file broker-cert-request.csr -storepass broker-ks-password

# Sign the CSR with the CA
openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -in broker-cert-request.csr -out broker-cert-signed.pem \
  -days 365 -passin pass:ca-password

# Import the CA certificate into the broker keystore
keytool -importcert -alias ca-cert -file ca-cert.pem \
  -keystore kafka.broker.keystore.jks -storepass broker-ks-password -noprompt

# Import the signed broker certificate into the broker keystore
keytool -importcert -alias broker -file broker-cert-signed.pem \
  -keystore kafka.broker.keystore.jks -storepass broker-ks-password
```

### Step 3: Generate Client Keystore and Truststore (for PDI)

```bash
# Generate client keystore with a key pair
keytool -genkeypair -alias pdi-client -keyalg RSA -keysize 2048 \
  -keystore kafka.client.keystore.jks -validity 365 \
  -storepass client-ks-password -keypass client-key-password \
  -dname "CN=pdi-client,OU=PDI,O=Workshop,L=City,ST=State,C=US"

# Create a certificate signing request (CSR)
keytool -certreq -alias pdi-client -keystore kafka.client.keystore.jks \
  -file client-cert-request.csr -storepass client-ks-password

# Sign the CSR with the CA
openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -in client-cert-request.csr -out client-cert-signed.pem \
  -days 365 -passin pass:ca-password

# Import the CA certificate into the client keystore
keytool -importcert -alias ca-cert -file ca-cert.pem \
  -keystore kafka.client.keystore.jks -storepass client-ks-password -noprompt

# Import the signed client certificate into the client keystore
keytool -importcert -alias pdi-client -file client-cert-signed.pem \
  -keystore kafka.client.keystore.jks -storepass client-ks-password

# Create the client truststore with the CA certificate
keytool -importcert -alias ca-cert -file ca-cert.pem \
  -keystore kafka.client.truststore.jks -storepass client-ts-password -noprompt
```

### Step 4: Create Broker Truststore

```bash
# Create the broker truststore with the CA certificate
keytool -importcert -alias ca-cert -file ca-cert.pem \
  -keystore kafka.broker.truststore.jks -storepass broker-ts-password -noprompt
```

### Summary of Generated Files

| File | Purpose | Used By |
|------|---------|---------|
| `ca-cert.pem` | Certificate Authority certificate | Signing only |
| `ca-key.pem` | Certificate Authority private key | Signing only (keep secure) |
| `kafka.broker.keystore.jks` | Broker identity (certificate + private key) | Kafka broker |
| `kafka.broker.truststore.jks` | Trusted CAs for broker | Kafka broker |
| `kafka.client.keystore.jks` | Client identity (certificate + private key) | PDI (`ssl.keystore.location`) |
| `kafka.client.truststore.jks` | Trusted CAs for client | PDI (`ssl.truststore.location`) |

> **Production note**: In production, replace self-signed certificates with certificates issued by your organization's CA or a public CA. Use separate keystores for each client application. Rotate certificates before expiry.

---

## Kafka Consumer: Complete Secured Configuration Example

Below is a complete example of a Kafka Consumer step's **Options tab** for SASL/SCRAM over SSL. This combines all the security properties with the standard consumer properties.

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | Standard consumer property |
| `enable.auto.commit` | `false` | Let PDI manage offsets |
| `security.protocol` | `SASL_SSL` | Enable SASL + SSL |
| `sasl.mechanism` | `SCRAM-SHA-256` | SCRAM authentication |
| `ssl.truststore.location` | `/opt/pdi/security/kafka.client.truststore.jks` | Absolute path to truststore |
| `ssl.truststore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Encrypted truststore password |
| `ssl.keystore.location` | `/opt/pdi/security/kafka.client.keystore.jks` | Absolute path to keystore |
| `ssl.keystore.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Encrypted keystore password |
| `ssl.key.password` | `Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4` | Encrypted private key password |
| `sasl.jaas.config` | `org.apache.kafka.common.security.scram.ScramLoginModule required username="pdi-consumer" password="Encrypted 2be98afc86aa7f2e4cb79ce10bee3c6e4";` | Inline JAAS config |

> **Tip**: The standard consumer properties (`auto.offset.reset`, `enable.auto.commit`, etc.) are configured alongside the security properties in the same Options tab. Security properties do not replace the standard ones.

---

## Kafka Producer: Applying the Same Security Settings

The Kafka Producer step has its own **Options tab** that accepts the same security properties. When your pipeline both consumes from and produces to secured Kafka clusters, you must configure security in **both** steps.

| Kafka Consumer Options Tab | Kafka Producer Options Tab |
|---------------------------|---------------------------|
| `security.protocol: SASL_SSL` | `security.protocol: SASL_SSL` |
| `sasl.mechanism: SCRAM-SHA-256` | `sasl.mechanism: SCRAM-SHA-256` |
| `ssl.truststore.location: /path/...` | `ssl.truststore.location: /path/...` |
| `ssl.truststore.password: Encrypted ...` | `ssl.truststore.password: Encrypted ...` |
| `ssl.keystore.location: /path/...` | `ssl.keystore.location: /path/...` |
| `ssl.keystore.password: Encrypted ...` | `ssl.keystore.password: Encrypted ...` |
| `ssl.key.password: Encrypted ...` | `ssl.key.password: Encrypted ...` |
| `sasl.jaas.config: ...` | `sasl.jaas.config: ...` |

> **Different credentials**: In production, the consumer and producer may use **different** usernames/credentials with different Kafka ACL permissions. The consumer user needs READ access to the source topic and its consumer group. The producer user needs WRITE access to the target topic.

---

## Debugging Security Issues

### Common Errors and Fixes

#### "SSL handshake failed"

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Truststore missing CA cert | `sun.security.provider.certpath.SunCertPathBuilderException` | Import the broker's CA cert into the client truststore |
| Wrong truststore password | `java.io.IOException: Keystore was tampered with` | Verify the password with `keytool -list -keystore truststore.jks` |
| Expired certificate | `NotAfter` date in the past | Regenerate certificates with longer validity |
| Wrong truststore path | `java.io.FileNotFoundException` | Verify the absolute path exists and PDI has read permission |

#### "Authentication failed"

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Wrong username/password | `AuthenticationException` in logs | Verify credentials; re-encrypt password with `Encr` tool |
| Wrong SASL mechanism | `UnsupportedSaslMechanismException` | Match `sasl.mechanism` to broker's `sasl.enabled.mechanisms` |
| Missing JAAS config | `LoginException: No LoginModule found` | Add `sasl.jaas.config` property with correct LoginModule class |
| JAAS config formatting | `LoginException: Unable to parse` | Ensure single line, trailing semicolon, correct quoting |

#### "GSSAPI/Kerberos failed"

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Missing `krb5.conf` | `Cannot locate default realm` | Set `-Djava.security.krb5.conf` in Spoon startup |
| Expired keytab | `KrbException: Key version mismatch` | Regenerate keytab with `kadmin` |
| Wrong service name | `GSSException: No valid credentials` | Set `sasl.kerberos.service.name` to match broker principal |
| Clock skew | `KrbException: Clock skew too great` | Sync clocks with NTP; Kerberos requires < 5 min skew |

### Enabling SSL Debug Logging

To diagnose SSL handshake issues, enable Java SSL debug output in Spoon's startup script:

```bash
# In spoon.sh or set-pentaho-env.sh:
export JAVA_OPTS="$JAVA_OPTS -Djavax.net.debug=ssl:handshake"
```

This produces verbose SSL handshake logs in the PDI console. **Remove this setting after debugging** -- it generates significant log output.

### Verifying Keystore and Truststore Contents

Use `keytool` to inspect your JKS files before configuring PDI:

```bash
# List all certificates in the truststore
keytool -list -keystore kafka.client.truststore.jks -storepass client-ts-password

# List all entries in the keystore (including private keys)
keytool -list -v -keystore kafka.client.keystore.jks -storepass client-ks-password

# Verify a certificate's expiry date
keytool -list -v -keystore kafka.client.keystore.jks -storepass client-ks-password \
  -alias pdi-client | grep "Valid from"
```

---

## Best Practices

### Credential Management

1. **Always encrypt passwords**: Use `Encr` for every password in the Options tab. Never store plaintext passwords in `.ktr` files
2. **Use PDI variables for paths**: Store keystore/truststore paths in `kettle.properties` or as variables (`${SSL_TRUSTSTORE_PATH}`) so they can differ between environments
3. **Credential rotation**: Establish a schedule for rotating passwords, certificates, and keytabs. Update PDI transformations and re-encrypt new passwords with `Encr`
4. **Secrets management**: For production, load credentials from a secrets manager (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault) via PDI variables rather than embedding them in transformation files

### Certificate Management

1. **Separate keystores per application**: Each PDI instance/application should have its own keystore with its own client certificate. This enables per-application ACLs and independent certificate rotation
2. **Monitor certificate expiry**: Set up alerts for certificates approaching expiry. Use `keytool -list -v` to check `Valid from` / `until` dates
3. **Use strong key sizes**: RSA 2048-bit minimum; 4096-bit recommended for long-lived certificates
4. **Secure private keys**: Restrict file-system permissions on keystore files (`chmod 600`). The PDI service account should be the only user with read access

### Access Control

1. **Least privilege**: Grant each PDI consumer/producer only the minimum Kafka ACL permissions required:
   - Consumer: `READ` on topic, `READ` on consumer group
   - Producer: `WRITE` on topic, `DESCRIBE` on topic
2. **Separate consumer and producer credentials**: Use different usernames for consuming and producing so that ACLs can be scoped independently
3. **Consumer group ACLs**: Restrict which users can join which consumer groups to prevent unauthorized consumers from reading sensitive topics
4. **Topic-level ACLs**: Grant access per topic, not cluster-wide

### Network Security

1. **Use `SASL_SSL`, not `SASL_PLAINTEXT`**: Always encrypt the connection when using SASL. `SASL_PLAINTEXT` transmits SASL handshake data (including PLAIN passwords) in cleartext
2. **Disable insecure listeners**: In production, configure the Kafka broker to only expose SSL or SASL_SSL listeners. Remove `PLAINTEXT` listeners
3. **Firewall rules**: Restrict network access to Kafka broker ports (typically 9093 for SSL, 9094 for SASL_SSL) to authorized client hosts only

---

## Security Protocol Quick Reference

| Protocol | Encryption | Authentication | Use Case |
|----------|-----------|----------------|----------|
| `PLAINTEXT` | No | No | Development only (workshop Docker environment) |
| `SSL` | Yes | Certificate-based (mTLS) | Encryption without SASL; client identity via certificate |
| `SASL_PLAINTEXT` | No | Yes (SASL) | **Not recommended** -- credentials sent in cleartext |
| `SASL_SSL` | Yes | Yes (SASL + optional mTLS) | Production recommended -- encryption + authentication |

| SASL Mechanism | Credential Type | Strength | Infrastructure Required |
|----------------|----------------|----------|------------------------|
| `PLAIN` | Username/password | Basic (relies on SSL for protection) | Username/password configured on broker |
| `SCRAM-SHA-256` | Username/password | Strong (salted challenge-response) | SCRAM users created via `kafka-configs.sh` |
| `SCRAM-SHA-512` | Username/password | Strong (larger hash) | SCRAM users created via `kafka-configs.sh` |
| `GSSAPI` | Kerberos ticket | Enterprise (centralized identity) | KDC, keytabs, `krb5.conf` |

---

## Summary

This scenario provides a reference guide for securing Kafka communication in PDI transformations. The key takeaways are:

- All security properties are configured in the **Options tab** of both the Kafka Consumer and Kafka Producer steps
- **SSL encryption** requires truststore (and optionally keystore) JKS files and their passwords
- **SASL authentication** adds `sasl.mechanism` and `sasl.jaas.config` properties with the appropriate LoginModule class
- **PDI's `Encr` tool** should be used to encrypt all passwords, producing `Encrypted [hex]` values for the Options tab
- The same security configuration applies to both Kafka Consumer and Kafka Producer steps
- In production, combine multiple security layers: SSL encryption + SASL authentication + Kafka ACLs + credential rotation

**Previous**: [Scenario 5: Multi-Topic Consumer with Kafka Producer](scenario-5-multi-topic.md)

---

**Related Documentation**:
- [Workshop Guide -- Security Configuration](../WORKSHOP-GUIDE.md#security-configuration) -- SSL and SASL reference
- [Workshop Guide -- PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) -- All 6 configuration tabs
- [Workshop Guide -- PDI Kafka Producer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-producer-configuration) -- Producer Options tab
- [Workshop Guide -- Best Practices](../WORKSHOP-GUIDE.md#best-practices) -- Security best practices
