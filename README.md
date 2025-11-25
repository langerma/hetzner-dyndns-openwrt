# Hetzner DynDNS Script

A shell script for automatic dynamic DNS updates using the **Hetzner Cloud API**. Perfect for OpenWRT routers and other Linux systems to keep your DNS records synchronized with your current public IP address.

## Features

- ✅ Works with the **new Hetzner Cloud API** (`api.hetzner.cloud`)
- ✅ Supports both **IPv4 (A records)** and **IPv6 (AAAA records)**
- ✅ Automatic IP detection via Hetzner's IP service
- ✅ Only updates DNS when IP address changes (avoids unnecessary API calls)
- ✅ Support for both Zone ID and Zone Name lookup
- ✅ Configurable TTL values
- ✅ Compatible with OpenWRT and standard Linux systems
- ✅ Comprehensive error handling and logging

## Requirements

- `curl` - for API requests
- `jq` - for JSON parsing
- A Hetzner Cloud account with DNS zones
- A Hetzner Cloud API token with DNS permissions

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/langerma/hetzner-dyndns-openwrt/main/dyndns.sh
chmod +x dyndns.sh
```

2. Get your API token:
   - Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
   - Navigate to your project → Security → API Tokens
   - Create a new token with **Read & Write** permissions for **Zones**

3. Migrate your DNS zones (if needed):
   - Old DNS zones from `dns.hetzner.com` need to be migrated to the Cloud Console
   - Follow the [migration guide](https://docs.hetzner.com/networking/dns/migration-to-hetzner-console/process/)

## Usage

### Basic Usage

```bash
# Update a subdomain (creates pr.example.com)
./dyndns.sh -Z example.com -n pr

# Update with explicit API token
HETZNER_AUTH_API_TOKEN="your-token-here" ./dyndns.sh -Z example.com -n dyn

# Update IPv6 record
./dyndns.sh -Z example.com -n dyn -T AAAA

# Update root domain
./dyndns.sh -Z example.com -n @ -T A

# Use Zone ID instead of name
./dyndns.sh -z 123456 -n dyn
```

### Command-Line Options

| Option | Description | Required |
|--------|-------------|----------|
| `-Z` | Zone name (e.g., `example.com`) | Yes (or `-z`) |
| `-z` | Zone ID | Yes (or `-Z`) |
| `-n` | Record name (subdomain or `@` for root) | Yes |
| `-T` | Record type: `A` or `AAAA` (default: `A`) | No |
| `-t` | TTL in seconds (default: `60`) | No |
| `-h` | Show help | No |

### Environment Variables

You can set these environment variables instead of command-line options:

```bash
export HETZNER_AUTH_API_TOKEN="your-token-here"
export HETZNER_ZONE_NAME="example.com"
export HETZNER_RECORD_NAME="dyn"
export HETZNER_RECORD_TYPE="A"
export HETZNER_RECORD_TTL="60"

./dyndns.sh -n dyn
```

## Automated Updates (Cron)

### Option 1: Inline Environment Variable

```bash
# Edit crontab
crontab -e

# Add line to update every 5 minutes
*/5 * * * * HETZNER_AUTH_API_TOKEN="your-token" /root/dyndns.sh -Z example.com -n dyn >> /tmp/dyndns.log 2>&1
```

### Option 2: Configuration File (Recommended)

Create a config file `/root/.hetzner-dyndns.conf`:

```bash
HETZNER_AUTH_API_TOKEN="your-token-here"
HETZNER_ZONE_NAME="example.com"
HETZNER_RECORD_NAME="dyn"
HETZNER_RECORD_TYPE="A"
HETZNER_RECORD_TTL="60"
```

Secure the file:
```bash
chmod 600 /root/.hetzner-dyndns.conf
```

Add to crontab:
```bash
*/5 * * * * . /root/.hetzner-dyndns.conf && /root/dyndns.sh -Z ${HETZNER_ZONE_NAME} -n ${HETZNER_RECORD_NAME} >> /tmp/dyndns.log 2>&1
```

### OpenWRT Specific

For OpenWRT, the logs are automatically sent to syslog. Check logs with:
```bash
logread | grep dyndns
```

## Security Best Practices

1. **Use dedicated API tokens** - Create separate tokens for each router/device
2. **Minimal permissions** - Only grant DNS Zones read/write permissions
3. **Token naming** - Use descriptive names like "DynDNS-Router1", "DynDNS-Router2"
4. **Secure storage** - Use `chmod 600` for config files
5. **Token rotation** - Periodically rotate tokens for enhanced security

## Troubleshooting

### No zones found

**Error:** `No zones found in your Hetzner account`

**Solution:** Your DNS zones need to be migrated to the Hetzner Cloud Console:
1. Visit [dns.hetzner.com](https://dns.hetzner.com/)
2. Follow the migration guide
3. Ensure zones are visible in Cloud Console

### API Token Invalid

**Error:** `API Error (unauthorized): Invalid token`

**Solution:**
- Verify token is copied correctly (no extra spaces)
- Ensure token has **Zones** read/write permissions
- Create a new token if needed

### Record name doubling

**Error:** Creates `subdomain.example.com.example.com`

**Solution:** This has been fixed in v2.0. Update to the latest version.

### Can't determine IP address

**Error:** `Apparently there is a problem in determining the public ip address`

**Solution:**
- Check internet connectivity
- Verify `https://ip.hetzner.com` is accessible
- For IPv6, ensure your system has a public IPv6 address

## Migration from Old Script

If you're migrating from the old `dns.hetzner.com` API script:

1. **Migrate your DNS zones** to Hetzner Cloud Console
2. **Create a new API token** in Cloud Console (old tokens won't work)
3. **Update your script** to this new version
4. **Update cron jobs** with the new API token

The script usage remains largely the same, but uses the new API endpoints.

## API Rate Limits

The Hetzner Cloud API has rate limits. For DynDNS usage:
- Recommended check interval: **5 minutes**
- Script only makes API calls when IP changes
- Avoid checking more frequently than every 2 minutes

## Examples

### Multiple Subdomains

```bash
# Update multiple subdomains for different services
HETZNER_AUTH_API_TOKEN="token" ./dyndns.sh -Z example.com -n home
HETZNER_AUTH_API_TOKEN="token" ./dyndns.sh -Z example.com -n vpn
HETZNER_AUTH_API_TOKEN="token" ./dyndns.sh -Z example.com -n nas
```

### Dual Stack (IPv4 + IPv6)

```bash
# Update both A and AAAA records
./dyndns.sh -Z example.com -n dyn -T A
./dyndns.sh -Z example.com -n dyn -T AAAA
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

This script is based on the excellent work by [FarrowStrange](https://github.com/FarrowStrange) in the [hetzner-api-dyndns](https://github.com/FarrowStrange/hetzner-api-dyndns) repository.

The original script was designed for the legacy Hetzner DNS API (`dns.hetzner.com`). This version has been completely rewritten to work with the new Hetzner Cloud API (`api.hetzner.cloud`) while maintaining compatibility with OpenWRT routers and similar systems.

## License

This project is open source and available under the MIT License.

## Changelog

### v2.0 (2025-11-25)
- Complete rewrite for new Hetzner Cloud API (`api.hetzner.cloud`)
- Fixed record name doubling issue
- Improved error handling and logging
- Added support for environment variables
- Enhanced security with Bearer token authentication

### v1.3 (Original)
- Support for old DNS API (`dns.hetzner.com`)
- Basic IPv4/IPv6 support

## Support

- Hetzner Cloud API Documentation: https://docs.hetzner.cloud/
- DNS Migration Guide: https://docs.hetzner.com/networking/dns/migration-to-hetzner-console/
- Issues: Please report issues on GitHub
