# RFQ lifecycle

```text
Open → competing Active quotes → one Filled quote → atomic settlement → immutable receipt
Open → Cancelled
Open → Expired
Active quote → Cancelled
Active losing/expired quote → Released
```

Public RFQs allow any active registered provider. Invite-only RFQs use a bounded authorization
mapping and do not provide privacy. Every firm quote immediately reserves its complete buy amount.
No quote or RFQ supports partial fills.
