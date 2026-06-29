from typing import Annotated, Literal, Union
from pydantic import BaseModel, Field, model_validator


class Trigger(BaseModel):
    event: str
    repo: str


class Registry(BaseModel):
    base: str
    staging_suffix: str = "-staging"


class DaggerStage(BaseModel):
    name: str
    type: Literal["dagger"]
    function: str
    args: dict[str, str] = Field(default_factory=dict)
    depends_on: list[str] = Field(default_factory=list)


class ScriptStage(BaseModel):
    name: str
    type: Literal["skopeo", "dispatch"]
    script: str
    args: list[str] = Field(default_factory=list)
    depends_on: list[str] = Field(default_factory=list)


Stage = Annotated[Union[DaggerStage, ScriptStage], Field(discriminator="type")]


class NotificationChannel(BaseModel):
    channel: str


class Notifications(BaseModel):
    on_failure: list[NotificationChannel] = Field(default_factory=list)
    on_success: list[NotificationChannel] = Field(default_factory=list)


class Pipeline(BaseModel):
    name: str
    description: str | None = None
    triggers: list[Trigger]
    registry: Registry | None = None
    stages: list[Stage]
    notifications: Notifications | None = None

    @model_validator(mode="after")
    def _unique_stage_names(self) -> "Pipeline":
        seen: set[str] = set()
        for s in self.stages:
            if s.name in seen:
                raise ValueError(f"duplicate stage name: {s.name}")
            seen.add(s.name)
        return self
