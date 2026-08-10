"""Configuration tasks for speedmap trend analysis."""

from typing import Annotated
from ecoscope_workflows_core.decorators import task
from pydantic import Field


@task
def set_title_var(
    title: Annotated[str, Field(title="")],
) -> str:
    return title
