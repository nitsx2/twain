"""WeasyPrint Rx PDF renderer. Signature embedded as inline base64 PNG."""
from __future__ import annotations

import base64
from datetime import datetime
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, select_autoescape
from weasyprint import HTML

_TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=select_autoescape(["html"]),
)


def render_prescription_pdf(
    *,
    serial_number: str,
    doctor_full_name: str,
    specialty: str | None,
    registration_no: str | None,
    clinic_name: str | None,
    clinic_address: str | None,
    clinic_phone: str | None,
    signature_png: bytes | None,
    patient_name: str | None,
    patient_age: int | None,
    patient_sex: str | None,
    patient_code: int | None,
    diagnosis: str | None,
    medicines: list[dict[str, Any]],
    labs: list[str],
    lifestyle: list[str],
    advice: str | None,
    follow_up: str | None,
) -> bytes:
    sig_uri: str | None = None
    if signature_png:
        b64 = base64.b64encode(signature_png).decode("ascii")
        sig_uri = f"data:image/png;base64,{b64}"

    ctx = {
        "serial_number": serial_number,
        "date_str": datetime.utcnow().strftime("%d %b %Y"),
        "doctor_full_name": doctor_full_name,
        "specialty": specialty,
        "registration_no": registration_no,
        "clinic_name": clinic_name,
        "clinic_address": clinic_address,
        "clinic_phone": clinic_phone,
        "signature_data_uri": sig_uri,
        "patient_name": patient_name,
        "patient_age": patient_age,
        "patient_sex": patient_sex,
        "patient_code": patient_code,
        "diagnosis": diagnosis,
        "medicines": medicines,
        "labs": labs,
        "lifestyle": lifestyle,
        "advice": advice,
        "follow_up": follow_up,
    }

    template = _env.get_template("prescription.html")
    html_str = template.render(**ctx)
    return HTML(string=html_str, base_url=str(_TEMPLATE_DIR)).write_pdf()
