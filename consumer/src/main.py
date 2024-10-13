import asyncio
import os

from azure.eventhub.aio import EventHubConsumerClient
from azure.eventhub.extensions.checkpointstoreblobaio import (
    BlobCheckpointStore,
)
from azure.identity.aio import DefaultAzureCredential


BLOB_STORAGE_ACCOUNT_URL = os.environ.get("BLOB_STORAGE_ACCOUNT_URL")
BLOB_CONTAINER_NAME = os.environ.get("BLOB_CONTAINER_NAME")
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE = os.environ.get("EVENT_HUB_FULLY_QUALIFIED_NAMESPACE")
EVENT_HUB_NAME = os.environ.get("EVENT_HUB_NAME")

credential = DefaultAzureCredential()

async def on_event(partition_context, event):
    # Print the event data.
    print(
        'Received the event: "{}" from the partition with ID: "{}"'.format(
            event.body_as_str(encoding="UTF-8"), partition_context.partition_id
        )
    )

    # Update the checkpoint so that the program doesn't read the events
    # that it has already read when you run it next time.
    await partition_context.update_checkpoint(event)


async def main():
    # Create an Azure blob checkpoint store to store the checkpoints.
    print("Creating a blob checkpoint store.")
    checkpoint_store = BlobCheckpointStore(
        blob_account_url=BLOB_STORAGE_ACCOUNT_URL,
        container_name=BLOB_CONTAINER_NAME,
        credential=credential,
    )

    # Create a consumer client for the event hub.
    print("Creating an event hub consumer client.")
    client = EventHubConsumerClient(
        fully_qualified_namespace=EVENT_HUB_FULLY_QUALIFIED_NAMESPACE,
        eventhub_name=EVENT_HUB_NAME,
        consumer_group="activepassive",
        checkpoint_store=checkpoint_store,
        credential=credential,
    )

    print("listening for events...")
    async with client:
        # Call the receive method. Read from the beginning of the partition
        # (starting_position: "-1")
        await client.receive(on_event=on_event, starting_position="-1")

    # Close credential when no longer needed.
    await credential.close()

if __name__ == "__main__":
    # Run the main method.
    asyncio.run(main())