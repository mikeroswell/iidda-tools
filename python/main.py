from fastapi import FastAPI, Request, HTTPException, Depends, FastAPI, Query
from iidda_api import *
from fastapi.responses import FileResponse
import nest_asyncio
from fastapi.openapi.utils import get_openapi
from jq import jq
import re
nest_asyncio.apply()

app = FastAPI(title="IIDDA API", swagger_ui_parameters={"defaultModelsExpandDepth": -1})

def generate_filters():
    dataset_list = get_dataset_list(all_metadata=True,clear_cache=False)
    data = jq('map_values(select(. != "No metadata.")) | [paths(scalars) as $p | [ ( [ [$p[]] | map(select(. | type != "number")) | .[] | tostring ][1:] | join(" ."))] | .[]] | unique').transform(dataset_list)
    for x in range(len(data)):
        data[x] = "." + data[x]
    return data

@app.get("/dataset_metadata")
async def datasets(all_metadata: bool = False, key: str = Query("", enum=generate_filters()),value: str ="",jq_query: str = ""):
    if (key == "" or value == "") and jq_query == "":
        return get_dataset_list(all_metadata,clear_cache=False)
    elif jq_query != "":
        data = get_dataset_list(all_metadata=True,clear_cache=False)
        return jq(jq_query).transform(data, multiple_output=True)
    elif key != "" and value != "":
        keys = key.split(" ")
        print(keys)
        data = get_dataset_list(all_metadata=True,clear_cache=False)
        if len(keys) > 1:
            return jq(f'map_values(select(. != "No metadata.") | select({keys[0]} | if type == "array" then select(.[] {keys[1]} | if type == "array" then select(.[] | contains("{value}")) else select(. | contains("{value}")) end) else select({keys[1]} | contains("{value}")) end))').transform(data)
        else:
            return jq(f'map_values(select(. != "No metadata.") | select({keys[0]} != null) | select({keys[0]} | if type == "array" then (.[] | contains("{value}")) else contains("{value}") end))').transform(data)

@app.get("/dataset/{dataset_name}")
async def dataset(dataset_name: str,response_type: str = Query("dataset_download", enum=sorted(["dataset_download", "pipeline_dependencies", "github_url", "raw_csv", "metadata", "csv_dialect", "data_dictionary"])), version: str = "latest", metadata: bool =False):
    if response_type == "pipeline_dependencies":
        return get_pipeline_dependencies(dataset_name,version)
    else:
        return get_dataset(dataset_name,version,metadata,response_type)


@app.post('/githubwebhook', include_in_schema=False)  # ‘/githubwebhook’ specifies which link will it work on 
async def webhook(req: Request):
    get_dataset_list(all_metadata="False",clear_cache=True)
    return "Cache cleared."

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="IIDDA API",
        version="1.0.0",
        description="Open toolchain for processing infectious disease datasets available through IIDDA and other repositories",
        routes=app.routes,
    )
    openapi_schema["info"]["x-logo"] = {
        "url": "https://brand.mcmaster.ca/app/uploads/2019/04/mcm-bw-rev.png"
    }
    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi