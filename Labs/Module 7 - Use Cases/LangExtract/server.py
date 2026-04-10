from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import langextract as lx

app = FastAPI(title='LangExtract Service')

class ExtractionItem(BaseModel):
    extraction_class: str
    extraction_text:  str

class ExampleData(BaseModel):
    text:        str
    extractions: List[ExtractionItem]

class ExtractRequest(BaseModel):
    text:              str
    prompt:            str
    examples:          List[ExampleData]
    model_id:          Optional[str] = 'llama3.1:8b'
    model_url:         Optional[str] = 'http://localhost:11434'
    max_char_buffer:   Optional[int] = 1000
    max_workers:       Optional[int] = 2
    extraction_passes: Optional[int] = 1

@app.post('/extract')
def extract(req: ExtractRequest):
    try:
        examples = [
            lx.data.ExampleData(
                text=e.text,
                extractions=[
                    lx.data.Extraction(
                        extraction_class=x.extraction_class,
                        extraction_text=x.extraction_text,
                    )
                    for x in e.extractions
                ],
            )
            for e in req.examples
        ]

        result = lx.extract(
            text_or_documents=req.text,
            prompt_description=req.prompt,
            examples=examples,
            language_model_type=lx.inference.OllamaLanguageModel,
            model_id=req.model_id,
            model_url=req.model_url,
            fence_output=False,
            use_schema_constraints=False,
            max_char_buffer=req.max_char_buffer,
            max_workers=req.max_workers,
            extraction_passes=req.extraction_passes,
        )

        return {
            'extractions': [
                {
                    'class':         e.extraction_class,
                    'text':          e.extraction_text,
                    'char_interval': e.char_interval,
                }
                for e in result.extractions
            ]
        }

    except Exception as ex:
        raise HTTPException(status_code=500, detail=str(ex))

@app.get('/health')
def health():
    return {'status': 'ok'}