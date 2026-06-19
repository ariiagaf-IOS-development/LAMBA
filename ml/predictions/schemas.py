from datetime import datetime, date
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class VehicleSchema(BaseModel):
    id: int
    brand: str
    model: str
    year: int
    vin: Optional[str] = None
    mileage_km: int
    fuel_type: str
    transmission: str
    usage_type: str


class EventSchema(BaseModel):
    id: int
    type: str
    title: str
    description: Optional[str] = None
    mileage_km: Optional[int] = None
    cost: Optional[float] = None
    event_date: datetime
    metadata: Optional[Dict[str, Any]] = None


class PartSchema(BaseModel):
    part_category: str
    part_name: str
    installed_at_mileage_km: Optional[int] = None
    last_service_mileage_km: Optional[int] = None
    last_service_date: Optional[datetime] = None


class PredictionRequestSchema(BaseModel):
    request_id: str
    vehicle: VehicleSchema
    events: List[EventSchema] = Field(default_factory=list)
    parts: List[PartSchema] = Field(default_factory=list)


class PredictionItemSchema(BaseModel):
    part_category: str
    part_name: str
    risk_level: RiskLevel
    risk_score: int = Field(ge=0, le=100)
    remaining_km: Optional[int] = None
    remaining_days: Optional[int] = None
    predicted_next_mileage: Optional[int] = None
    predicted_next_date: Optional[date] = None
    probability: float = Field(ge=0, le=1)
    recommendation: str
    explanation: str


class PredictionResponseSchema(BaseModel):
    vehicle_id: int
    model_version: str
    predictions: List[PredictionItemSchema]