// ignore_for_file: prefer_single_quotes, always_specify_types, avoid_escaping_inner_quotes

import 'package:fhir/r4.dart';

final patient1 = Patient.fromJson({
  "resourceType": "Patient",
  "id": "a2605b15-4f1b-5839-b4ce-fb7a6bc1005f",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T15:57:30.114-04:00",
    "source": "#lImg0hiEBWydjzU6",
    "profile": ["http://fhir.mimic.mit.edu/StructureDefinition/mimic-patient"]
  },
  "text": {
    "status": "generated",
    "div":
        "<div xmlns=\"http://www.w3.org/1999/xhtml\"><div class=\"hapiHeaderText\"><b>PATIENT_10005817 </b></div><table class=\"hapiPropertyTable\"><tbody><tr><td>Identifier</td><td>10005817</td></tr><tr><td>Date of birth</td><td><span>12 December 2066</span></td></tr></tbody></table></div>"
  },
  "extension": [
    {
      "url": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race",
      "extension": [
        {
          "url": "ombCategory",
          "valueCoding": {
            "system": "urn:oid:2.16.840.1.113883.6.238",
            "code": "2106-3",
            "display": "White"
          }
        },
        {"url": "text", "valueString": "White"}
      ]
    },
    {
      "url":
          "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity",
      "extension": [
        {
          "url": "ombCategory",
          "valueCoding": {
            "system": "urn:oid:2.16.840.1.113883.6.238",
            "code": "2186-5",
            "display": "Not Hispanic or Latino"
          }
        },
        {"url": "text", "valueString": "Not Hispanic or Latino"}
      ]
    },
    {
      "url": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex",
      "valueCode": "M"
    }
  ],
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/patient",
      "value": "10005817"
    }
  ],
  "name": [
    {"use": "official", "family": "Patient_10005817"}
  ],
  "gender": "male",
  "birthDate": "2066-12-12",
  "deceasedDateTime": "2135-01-19",
  "maritalStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
        "code": "M"
      }
    ]
  },
  "communication": [
    {
      "language": {
        "coding": [
          {"system": "urn:ietf:bcp:47", "code": "en"}
        ]
      }
    }
  ],
  "managingOrganization": {
    "reference": "Organization/ee172322-118b-5716-abbc-18e4c5437e15"
  }
});

final patient2 = Patient.fromJson({
  "resourceType": "Patient",
  "id": "a3a12d01-dc21-565b-89e2-da60e7fc80dc",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T15:35:42.480-04:00",
    "source": "#othC0Js5rqtLvGMt",
    "profile": ["http://fhir.mimic.mit.edu/StructureDefinition/mimic-patient"]
  },
  "text": {
    "status": "generated",
    "div":
        "<div xmlns=\"http://www.w3.org/1999/xhtml\"><div class=\"hapiHeaderText\"><b>PATIENT_10003046 </b></div><table class=\"hapiPropertyTable\"><tbody><tr><td>Identifier</td><td>10003046</td></tr><tr><td>Date of birth</td><td><span>02 January 2090</span></td></tr></tbody></table></div>"
  },
  "extension": [
    {
      "url": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race",
      "extension": [
        {
          "url": "ombCategory",
          "valueCoding": {
            "system": "urn:oid:2.16.840.1.113883.6.238",
            "code": "2106-3",
            "display": "White"
          }
        },
        {"url": "text", "valueString": "White"}
      ]
    },
    {
      "url":
          "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity",
      "extension": [
        {
          "url": "ombCategory",
          "valueCoding": {
            "system": "urn:oid:2.16.840.1.113883.6.238",
            "code": "2186-5",
            "display": "Not Hispanic or Latino"
          }
        },
        {"url": "text", "valueString": "Not Hispanic or Latino"}
      ]
    },
    {
      "url": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex",
      "valueCode": "M"
    }
  ],
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/patient",
      "value": "10003046"
    }
  ],
  "name": [
    {"use": "official", "family": "Patient_10003046"}
  ],
  "gender": "male",
  "birthDate": "2090-01-02",
  "maritalStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
        "code": "S"
      }
    ]
  },
  "communication": [
    {
      "language": {
        "coding": [
          {"system": "urn:ietf:bcp:47", "code": "en"}
        ]
      }
    }
  ],
  "managingOrganization": {
    "reference": "Organization/ee172322-118b-5716-abbc-18e4c5437e15"
  }
});

final observation1 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "70cedbd3-2ea1-5c02-b6a1-eb9af4a675a1",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T16:29:29.196-04:00",
    "source": "#M929wpMZAT8apN46",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-micro-org"
    ]
  },
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/observation-micro-org",
      "value": "90039-5685393-80018"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system":
              "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "laboratory"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/microbiology-organism",
        "code": "80018",
        "display": "MORGANELLA MORGANII"
      }
    ]
  },
  "subject": {"reference": "Patient/f77a5b72-65fd-5b20-8cef-6b6be4791265"},
  "effectiveDateTime": "2176-10-06T02:37:00-04:00",
  "hasMember": [
    {"reference": "Observation/be49ea8d-f89d-57ea-8ef6-8e08c7cde069"},
    {"reference": "Observation/ffeb031d-24c8-5238-8cfe-2250fdb1fbc7"},
    {"reference": "Observation/3ff4e2d3-6da2-50e9-a9ec-1f4fc0c86a87"},
    {"reference": "Observation/d49683d7-c527-51a6-9c92-003c8ab1c4d4"},
    {"reference": "Observation/84df24ab-c1f5-59f8-922b-51c545093de0"},
    {"reference": "Observation/a23f4baf-172a-5326-ab80-67797c52f7a4"},
    {"reference": "Observation/c9f3b8db-ef6f-5518-b2c6-de58af16f0b1"},
    {"reference": "Observation/47681425-0f8d-5c00-a2d9-4f5655fe7162"},
    {"reference": "Observation/5ca77d3b-4fda-506f-be50-dd94986c03d3"},
    {"reference": "Observation/8e44e983-89b4-558e-9fa1-b871a4d5e143"}
  ],
  "derivedFrom": [
    {"reference": "Observation/954d7003-acf6-51ad-8190-4b089e2aaa08"}
  ]
});
final observation2 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "717897cb-fbc3-5cc2-be49-5cd15c91cda0",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T17:21:29.881-04:00",
    "source": "#l2uuLrl23v657E9e",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-micro-org"
    ]
  },
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/observation-micro-org",
      "value": "90272-4513542-80056"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system":
              "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "laboratory"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/microbiology-organism",
        "code": "80056",
        "display": "GRAM POSITIVE RODS"
      }
    ]
  },
  "subject": {"reference": "Patient/4365e125-c049-525a-9459-16d5e6947ad2"},
  "valueString":
      "This culture contains mixed bacterial types (>=3) so an abbreviated workup is performed. Any growth of P.aeruginosa, S.aureus and beta hemolytic streptococci will be reported. IF THESE BACTERIA ARE NOT REPORTED, THEY ARE NOT PRESENT in this culture.  ",
  "derivedFrom": [
    {"reference": "Observation/552a87fe-93b2-5c3a-a05e-4a02a69993f2"}
  ]
});
final observation3 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "fb255ddc-d6ae-59d2-918b-b8570d9fb6b0",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T15:56:46.158-04:00",
    "source": "#p75OB1ybFcl8aqk2",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-micro-test"
    ]
  },
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/observation-micro-test",
      "value": "3413329-90039"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system":
              "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "laboratory"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/microbiology-test",
        "code": "90039",
        "display": "URINE CULTURE"
      }
    ]
  },
  "subject": {"reference": "Patient/3886cafb-65f4-5789-9213-64678a202f82"},
  "effectiveDateTime": "2130-10-26T15:50:00-04:00",
  "valueString": "NO GROWTH.  ",
  "specimen": {"reference": "Specimen/5aa7bded-4749-519d-b4e6-29f3c26e32e2"}
});
final observation4 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "fb5815bf-5bd1-5a5e-b13c-3262adeb64b5",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T15:47:44.895-04:00",
    "source": "#uLVztb6PW8JuGxCL",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-micro-test"
    ]
  },
  "identifier": [
    {
      "system": "http://fhir.mimic.mit.edu/identifier/observation-micro-test",
      "value": "3203946-90201"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system":
              "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "laboratory"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/microbiology-test",
        "code": "90201",
        "display": "Blood Culture, Routine"
      }
    ]
  },
  "subject": {"reference": "Patient/568cb149-804c-59e8-bdf5-816e8151cd22"},
  "encounter": {"reference": "Encounter/885857ae-ce5d-5537-b21e-40d0c45fe12a"},
  "effectiveDateTime": "2196-03-01T07:10:00-05:00",
  "valueString": "NO GROWTH.  ",
  "specimen": {"reference": "Specimen/253e817f-1810-5002-9b44-ec52101894a0"}
});
final observation5 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "ef03f176-c48e-5495-9ffa-b77c59ec67f2",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T15:31:42.535-04:00",
    "source": "#1V1dDIi1Cv4oOZUH",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-datetimeevents"
    ]
  },
  "identifier": [
    {
      "system":
          "http://fhir.mimic.mit.edu/identifier/observation-datetimeevents",
      "value": "35479615-2156-05-19 03:56:00-224186"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system": "http://fhir.mimic.mit.edu/CodeSystem/observation-category",
          "code": "Access Lines - Invasive"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/d-items",
        "code": "224186",
        "display": "PICC Line Dressing Change"
      }
    ]
  },
  "subject": {"reference": "Patient/e1de99bc-3bc5-565e-9ee6-69675b9cc267"},
  "encounter": {"reference": "Encounter/d10c78ce-851f-5267-a3b7-c8834cb186f4"},
  "effectiveDateTime": "2156-05-19T03:56:00-04:00",
  "issued": "2156-05-19T03:56:00-04:00",
  "valueDateTime": "2156-05-16T14:00:00-04:00"
});
final observation6 = Observation.fromJson({
  "resourceType": "Observation",
  "id": "ef0771a2-ad06-5e14-bbd6-c9e271ab4b0b",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2022-05-24T18:03:13.483-04:00",
    "source": "#ww22qxyrluZ88zU3",
    "profile": [
      "http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-datetimeevents"
    ]
  },
  "identifier": [
    {
      "system":
          "http://fhir.mimic.mit.edu/identifier/observation-datetimeevents",
      "value": "30932571-2116-03-03 20:00:00-224288"
    }
  ],
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system": "http://fhir.mimic.mit.edu/CodeSystem/observation-category",
          "code": "Access Lines - Invasive"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://fhir.mimic.mit.edu/CodeSystem/d-items",
        "code": "224288",
        "display": "Arterial line Insertion Date"
      }
    ]
  },
  "subject": {"reference": "Patient/4f773083-7f4d-5378-b839-c24ca1e15434"},
  "encounter": {"reference": "Encounter/6b2b66d0-2417-5ce8-b852-581fe9dcb5d2"},
  "effectiveDateTime": "2116-03-03T20:00:00-05:00",
  "issued": "2116-03-03T20:01:00-05:00",
  "valueDateTime": "2116-02-29T00:00:00-05:00"
});
