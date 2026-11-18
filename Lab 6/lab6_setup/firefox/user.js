// Classroom Firefox profile: deterministic networking and no first-run UI.
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("datareporting.policy.firstRunURL", "");
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.migrate.automigrate.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);

// Keep DNS and transport behavior visible to the lab firewall.
user_pref("network.trr.mode", 5);              // disable DNS-over-HTTPS
user_pref("network.http.http3.enabled", false); // disable QUIC/HTTP3
user_pref("network.dns.disableIPv6", true);     // use IPv4 for this exercise
// Start each lab browser session with direct networking. Students deliberately
// change this later when configuring the SSH SOCKS evasion exercise.
user_pref("network.proxy.type", 0);
