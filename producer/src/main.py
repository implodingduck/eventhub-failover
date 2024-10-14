import asyncio
import datetime
import logging
import os
import uuid

from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient
from azure.identity.aio import DefaultAzureCredential

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from logging.config import dictConfig

from .log_config import log_config

dictConfig(log_config)
logger = logging.getLogger("api-logger")

app = FastAPI()

EVENT_HUB_FULLY_QUALIFIED_NAMESPACE = os.environ.get("EVENT_HUB_FULLY_QUALIFIED_NAMESPACE")
EVENT_HUB_NAME = os.environ.get("EVENT_HUB_NAME")
credential = DefaultAzureCredential()
producerclient = EventHubProducerClient(
        fully_qualified_namespace=EVENT_HUB_FULLY_QUALIFIED_NAMESPACE,
        eventhub_name=EVENT_HUB_NAME,
        credential=credential,
)

origins = [
    "*"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/produce")
async def produce():
    async with producerclient:
        # Create a batch.
        event_data_batch = await producerclient.create_batch()

        now = datetime.datetime.now()
        # Add events to the batch.
        event_data_batch.add(EventData(f"{now}: {uuid.uuid4()}"))
        event_data_batch.add(EventData(f"{now}: {uuid.uuid4()}"))
        event_data_batch.add(EventData(f"{now}: {uuid.uuid4()}"))

        # Send the batch of events to the event hub.
        await producerclient.send_batch(event_data_batch)

    
    return {"message": f"{now}: Events produced!"}