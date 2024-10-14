# eventhub-failover

## For local testing
```
az ad sp create-for-rbac -n "REPLACEME-eh-fo-spn" --role "Azure Event Hubs Data Owner" --scopes $RG_ID
```

Additional roles needed: 
* Azure Event Hubs Data Owner for secondary
* Azure Data Blob Owner on Storage Accounts

Setup .env file 
```
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=
AZURE_TENANT_ID=
AZURE_SUBSCRIPTION_ID=
RG_ID=
RG_ID2=
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE=
EVENT_HUB_NAME=
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_PRIMARY=
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_SECONDARY=
BLOB_STORAGE_ACCOUNT_URL=
BLOB_CONTAINER_NAME=
```

Run `./docker-stuff.sh`