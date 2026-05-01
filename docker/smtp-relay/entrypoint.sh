#!/usr/bin/env sh
set -eu

MAILNAME="${MAILNAME:-localdomain}"
RELAYHOST="${RELAYHOST:-}"
RELAYPORT="${RELAYPORT:-587}"
RELAYUSERNAME="${RELAYUSERNAME:-}"
RELAYPASSWORD="${RELAYPASSWORD:-}"
RELAYUSERNAME_FILE="${RELAYUSERNAME_FILE:-}"
RELAYPASSWORD_FILE="${RELAYPASSWORD_FILE:-}"

if [ -z "$RELAYUSERNAME" ] && [ -n "$RELAYUSERNAME_FILE" ] && [ -f "$RELAYUSERNAME_FILE" ]; then
  RELAYUSERNAME="$(cat "$RELAYUSERNAME_FILE")"
fi

if [ -z "$RELAYPASSWORD" ] && [ -n "$RELAYPASSWORD_FILE" ] && [ -f "$RELAYPASSWORD_FILE" ]; then
  RELAYPASSWORD="$(cat "$RELAYPASSWORD_FILE")"
fi

echo "$MAILNAME" > /etc/mailname

postconf -e "myhostname = $MAILNAME"
postconf -e "mydestination = localhost"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "mynetworks = 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
postconf -e "maillog_file = /dev/stdout"

if [ -n "$RELAYHOST" ]; then
  postconf -e "relayhost = [$RELAYHOST]:$RELAYPORT"
fi

if [ -n "$RELAYUSERNAME" ] && [ -n "$RELAYPASSWORD" ] && [ -n "$RELAYHOST" ]; then
  postconf -e "smtp_sasl_auth_enable = yes"
  postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
  postconf -e "smtp_sasl_security_options = noanonymous"
  postconf -e "smtp_sasl_tls_security_options = noanonymous"

  printf '[%s]:%s %s:%s\n' "$RELAYHOST" "$RELAYPORT" "$RELAYUSERNAME" "$RELAYPASSWORD" > /etc/postfix/sasl_passwd
  postmap /etc/postfix/sasl_passwd
  chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
fi

exec postfix start-fg
