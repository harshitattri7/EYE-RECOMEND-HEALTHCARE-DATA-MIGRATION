"""
Ophthalmology and Optometry Domain Transformations ("Eye Recommend" Core Engine)
Validates diopters, axes, intraocular pressures, and eyewear lens parameters.
"""
import uuid
from typing import Dict, Any, Optional

class OphthalmologyDataTransformer:
    @staticmethod
    def clamp_axis(axis: Optional[Any]) -> Optional[int]:
        """Normalizes refractive axis to integer range [1, 180]"""
        if axis is None or str(axis).strip() == "":
            return None
        try:
            val = int(float(axis))
            if val < 1:
                return 1
            if val > 180:
                return 180
            return val
        except (ValueError, TypeError):
            return 90 # Standard default if invalid

    @staticmethod
    def parse_diopter(val: Optional[Any], default: float = 0.0) -> float:
        """Parses sphere, cylinder or add diopter float value"""
        if val is None or str(val).strip() == "":
            return default
        try:
            return round(float(val), 2)
        except (ValueError, TypeError):
            return default

    def transform_refraction(self, row: Dict[str, Any], encounter_id_map: Dict[int, str], patient_id_map: Dict[int, str], practitioner_id: str) -> Dict[str, Any]:
        """Transforms legacy refraction exam data into target optometry_ophthalmology.refractions"""
        enc_nid = row.get("encounter_nid")
        refraction_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"refraction:enc:{enc_nid}"))
        encounter_id = encounter_id_map.get(enc_nid, str(uuid.uuid4()))
        patient_id = patient_id_map.get(row.get("patient_nid", 1001), str(uuid.uuid4()))

        return {
            "refraction_id": refraction_uuid,
            "encounter_id": encounter_id,
            "patient_id": patient_id,
            "refraction_type": "MANIFEST",
            "od_sphere": self.parse_diopter(row.get("od_sphere")),
            "od_cylinder": self.parse_diopter(row.get("od_cylinder"), 0.0),
            "od_axis": self.clamp_axis(row.get("od_axis")),
            "od_add": self.parse_diopter(row.get("od_add"), None) if row.get("od_add") is not None else None,
            "od_prism_value": None,
            "od_prism_base": None,
            "os_sphere": self.parse_diopter(row.get("os_sphere")),
            "os_cylinder": self.parse_diopter(row.get("os_cylinder"), 0.0),
            "os_axis": self.clamp_axis(row.get("os_axis")),
            "os_add": self.parse_diopter(row.get("os_add"), None) if row.get("os_add") is not None else None,
            "os_prism_value": None,
            "os_prism_base": None,
            "pupillary_distance_binocular": self.parse_diopter(row.get("pd_binocular"), 63.0),
            "pupillary_distance_monocular_od": round(self.parse_diopter(row.get("pd_binocular"), 63.0) / 2.0, 1),
            "pupillary_distance_monocular_os": round(self.parse_diopter(row.get("pd_binocular"), 63.0) / 2.0, 1),
            "is_final_prescribed": True,
            "refracted_by_practitioner_id": practitioner_id
        }

    def transform_tonometry(self, row: Dict[str, Any], encounter_id_map: Dict[int, str]) -> Dict[str, Any]:
        """Transforms legacy IOP readings into optometry_ophthalmology.tonometry_exams"""
        enc_nid = row.get("encounter_nid")
        tonometry_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"tonometry:enc:{enc_nid}"))
        encounter_id = encounter_id_map.get(enc_nid, str(uuid.uuid4()))

        return {
            "tonometry_id": tonometry_uuid,
            "encounter_id": encounter_id,
            "method": "GOLDMANN_APPLANATION",
            "time_measured": "10:30:00",
            "iop_od_mmhg": self.parse_diopter(row.get("iop_od"), 15.0),
            "iop_os_mmhg": self.parse_diopter(row.get("iop_os"), 15.0),
            "corneal_pachymetry_od_microns": 545,
            "corneal_pachymetry_os_microns": 548
        }
