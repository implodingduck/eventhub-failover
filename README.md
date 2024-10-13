# eventhub-failover

## For local testing
```
az ad sp create-for-rbac -n "REPLACEME-eh-fo-spn" --role "Azure Event Hubs Data Owner" --scopes $RG_ID
az role assignment create --assignee $AZURE_CLIENT_ID --role "Azure Event Hubs Data Owner" --scope $RG_ID2
```