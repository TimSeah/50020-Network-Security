$TTL 300
@   IN  SOA ns.attackerpage.com. admin.attackerpage.com. (
        2026091502 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  ns.attackerpage.com.
    IN  A   10.11.2.8
ns  IN  A   10.11.2.8
www IN  A   10.11.2.8
