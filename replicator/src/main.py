import asyncio
import os
import datetime

from azure.eventhub import EventData
from azure.eventhub.aio import EventHubConsumerClient, EventHubProducerClient
from azure.eventhub.extensions.checkpointstoreblobaio import (
    BlobCheckpointStore,
)
from azure.identity.aio import DefaultAzureCredential


BLOB_STORAGE_ACCOUNT_URL = os.environ.get("BLOB_STORAGE_ACCOUNT_URL")
BLOB_CONTAINER_NAME = os.environ.get("BLOB_CONTAINER_NAME")
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_PRIMARY = os.environ.get("EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_PRIMARY")
EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_SECONDARY = os.environ.get("EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_SECONDARY")

EVENT_HUB_NAME = os.environ.get("EVENT_HUB_NAME")
EVENT_HUB_CONSUMER_GROUP = os.environ.get("EVENT_HUB_CONSUMER_GROUP", "$Default")

credential = DefaultAzureCredential()

producerclient = EventHubProducerClient(
        fully_qualified_namespace=EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_SECONDARY,
        eventhub_name=EVENT_HUB_NAME,
        credential=credential,
)


async def on_event(partition_context, event):
    # Print the event data.
    print(f"Received the event: '{event.body_as_str(encoding="UTF-8")}' from the partition with ID: '{partition_context.partition_id}', with message_id {event.message_id} and sequence_number {event.sequence_number}.")
    
    print(f"Replicating event {event.sequence_number}...")
    async with producerclient:
        # Create a batch.
        event_data_batch = await producerclient.create_batch()

        # Add events to the batch.
        now = datetime.datetime.now()
        event_data_batch.add(EventData(f"{event.body_as_str(encoding="UTF-8")} (replicated)"))

        # Send the batch of events to the event hub.
        await producerclient.send_batch(event_data_batch)
        print(f"Done replicating event {event.sequence_number}...")

    # Update the checkpoint so that the program doesn't read the events
    # that it has already read when you run it next time.
    await partition_context.update_checkpoint(event)


async def main():
    # Create an Azure blob checkpoint store to store the checkpoints.
    print("Creating a blob checkpoint store.")
    checkpoint_store = BlobCheckpointStore(
        blob_account_url=BLOB_STORAGE_ACCOUNT_URL,
        container_name=f"{BLOB_CONTAINER_NAME}-{EVENT_HUB_CONSUMER_GROUP}",
        credential=credential,
    )

    # Create a consumer client for the event hub.
    print("Creating an event hub consumer client.")
    client = EventHubConsumerClient(
        fully_qualified_namespace=EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_PRIMARY,
        eventhub_name=EVENT_HUB_NAME,
        consumer_group=EVENT_HUB_CONSUMER_GROUP,
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