$TTL 300
@   IN  SOA ns.attackerpage.com. admin.example.com. (
        2026091501 ; serial - increase this after edits
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  ns.attackerpage.com.
    IN  A   10.11.2.8
www IN  A   10.11.2.8
login IN A  10.11.2.8
