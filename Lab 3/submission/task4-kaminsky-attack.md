# Task 4 — Kaminsky Attack Demonstration

## Method

I ran the instructor-provided [`attack.py`](../scripts/attack.py) on node3 with `num_responses` set to 20, 50, and 200 in separate runs. Each run queried a new, uncached subdomain of `example.com` and sent that many forged DNS replies to node2. I captured node2's `eth0` traffic in Wireshark. Times below are relative to the start of each separate capture.

The forged replies claimed to come from `108.162.195.228:53` and targeted node2's fixed upstream DNS port `12345`. They proposed an A answer of `66.66.66.66` and an `example.com` NS record pointing to `ns.attackerpage.com`.

## Results

| Forged replies | Query name | First upstream query: time, destination, TXID | Legitimate reply time | Forged replies before legitimate reply | Result |
| ---: | --- | --- | ---: | ---: | --- |
| 20 | `vnztg.example.com` | 0.000311971 s, `173.245.58.162`, `0x1911` | 0.090794520 s | 20 | Legitimate SOA response; no forged A answer |
| 50 | `dfpbg.example.com` | 0.000348293 s, `108.162.192.162`, `0xf410` | 0.043552855 s | 50 | Legitimate SOA response; no forged A answer |
| 200 | `xjypw.example.com` | 0.000466255 s, `172.64.32.162`, `0x72c2` | 0.047623377 s | 200 | Legitimate SOA response; no forged A answer |

In all three runs, every forged reply arrived **after** node2's upstream query and **before** its legitimate reply. The 200-response setting gave the best experimental coverage because it placed the most transaction ID guesses in that interval. None of the runs poisoned the response returned to node3.

The complete set of upstream destination IP addresses observed in these three runs was **`173.245.58.162`, `108.162.192.162`, and `172.64.32.162`**. The forged source IP, `108.162.195.228`, matched none of them. A resolver must match a response to its outstanding query, so this address mismatch prevented these forged replies from being accepted even if a transaction ID guess happened to match.

## Transaction ID probability

The DNS transaction ID has 65,536 possible values. If each forged reply chooses one independently and uniformly, the probability of at least one ID match is `1 − (1 − 1/65536)^N`:

| Replies (`N`) | Estimated chance of an ID match |
| ---: | ---: |
| 20 | 0.0305% |
| 50 | 0.0763% |
| 200 | 0.3047% |

These estimates concern the **ID alone**. Acceptance also requires the correct query name, server IP, UDP ports, and arrival while the upstream query is outstanding. The observed poisoning success rate was 0/3 runs.

## How the experiment could be improved

At a high level, the forged responses should be timed to an active upstream query, cover more distinct transaction IDs during that window, and match the server IP and UDP tuple selected by node2. Repeating with fresh uncached subdomains would provide further independent opportunities. Implementation of these changes was outside this task.

## Evidence

- 20 replies: [upstream query and forged replies](../screenshots/12-task4-20-upstream-query-and-forged-replies.png); [legitimate reply](../screenshots/13-task4-20-legitimate-response.png).
- 50 replies: [upstream query](../screenshots/15-task4-50-upstream-query.png); [legitimate reply](../screenshots/14-task4-50-legitimate-response.png); [50-reply count](../screenshots/17-task4-50-forged-response-count.png).
- 200 replies: [upstream query](../screenshots/18-task4-200-upstream-query-and-forged-replies.png); [legitimate reply](../screenshots/19-task4-200-legitimate-response.png); [200-reply count](../screenshots/20-task4-200-forged-response-count.png).
