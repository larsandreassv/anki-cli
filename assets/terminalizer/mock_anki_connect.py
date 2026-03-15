#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("ANKI_DEMO_PORT", "8766"))

DECKS = {
    "Japanese::RTK": 1001,
    "Japanese::WordWrite": 1002,
}

MODELS = {
    "RTK": {
        "fields": ["Keyword", "Kanji"],
        "templates": {
            "Card 1": {
                "Front": "{{Kanji}}",
                "Back": "{{FrontSide}}\n\n<hr id=answer>\n\n{{Keyword}}",
            }
        },
        "css": ".card { font-family: arial; }",
    },
    "WordWrite": {
        "fields": ["Reading", "Definition", "Kanji"],
        "templates": {
            "Card 1": {
                "Front": "{{Kanji}}",
                "Back": "{{FrontSide}}\n\n<hr id=answer>\n\n{{Reading}}<br>{{Definition}}",
            }
        },
        "css": ".card { font-family: arial; }",
    },
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"Anki-Connect"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        action = payload.get("action")
        params = payload.get("params", {})

        try:
            result = self.dispatch(action, params)
        except ValueError as exc:
            self.respond({"result": None, "error": str(exc)})
            return

        self.respond({"result": result, "error": None})

    def dispatch(self, action, params):
        if action == "version":
            return 6
        if action == "deckNames":
            return list(DECKS)
        if action == "deckNamesAndIds":
            return DECKS
        if action == "createDeck":
            deck = params.get("deck")
            if not deck:
                raise ValueError("missing deck")
            if deck not in DECKS:
                DECKS[deck] = max(DECKS.values(), default=1000) + 1
            return DECKS[deck]
        if action == "getDeckStats":
            decks = params.get("decks") or []
            result = {}
            for deck_name in decks:
                if deck_name not in DECKS:
                    raise ValueError(f"unknown deck: {deck_name}")
                deck_id = DECKS[deck_name]
                result[str(deck_id)] = {
                    "deck_id": deck_id,
                    "name": deck_name,
                    "new_count": 20,
                    "learn_count": 0,
                    "review_count": 0,
                    "total_in_deck": 100,
                }
            return result
        if action == "modelNames":
            return list(MODELS)
        if action == "modelFieldNames":
            model = self.require_model(params.get("modelName"))
            return MODELS[model]["fields"]
        if action == "modelTemplates":
            model = self.require_model(params.get("modelName"))
            return MODELS[model]["templates"]
        if action == "createModel":
            return self.create_model(params)
        if action == "modelFieldAdd":
            model = self.require_model(params.get("modelName"))
            field_name = params.get("fieldName")
            if not field_name:
                raise ValueError("missing fieldName")
            if field_name in MODELS[model]["fields"]:
                raise ValueError(f"field already exists: {field_name}")
            MODELS[model]["fields"].append(field_name)
            return None
        if action == "modelFieldRemove":
            model = self.require_model(params.get("modelName"))
            field_name = params.get("fieldName")
            if field_name not in MODELS[model]["fields"]:
                raise ValueError(f"unknown field: {field_name}")
            MODELS[model]["fields"].remove(field_name)
            return None
        if action == "modelFieldRename":
            model = self.require_model(params.get("modelName"))
            old_name = params.get("oldFieldName")
            new_name = params.get("newFieldName")
            if old_name not in MODELS[model]["fields"]:
                raise ValueError(f"unknown field: {old_name}")
            if new_name in MODELS[model]["fields"]:
                raise ValueError(f"field already exists: {new_name}")
            fields = MODELS[model]["fields"]
            fields[fields.index(old_name)] = new_name
            return None
        if action == "modelTemplateAdd":
            model = self.require_model(params.get("modelName"))
            template = params.get("template") or {}
            name = template.get("Name")
            if not name:
                raise ValueError("missing template.Name")
            if name in MODELS[model]["templates"]:
                raise ValueError(f"template already exists: {name}")
            MODELS[model]["templates"][name] = {
                "Front": template.get("Front", ""),
                "Back": template.get("Back", ""),
            }
            return None
        if action == "modelTemplateRemove":
            model = self.require_model(params.get("modelName"))
            template_name = params.get("templateName")
            if template_name not in MODELS[model]["templates"]:
                raise ValueError(f"unknown template: {template_name}")
            del MODELS[model]["templates"][template_name]
            return None
        if action == "modelTemplateRename":
            model = self.require_model(params.get("modelName"))
            old_name = params.get("oldTemplateName")
            new_name = params.get("newTemplateName")
            if old_name not in MODELS[model]["templates"]:
                raise ValueError(f"unknown template: {old_name}")
            if new_name in MODELS[model]["templates"]:
                raise ValueError(f"template already exists: {new_name}")
            templates = MODELS[model]["templates"]
            templates[new_name] = templates.pop(old_name)
            return None
        if action == "canAddNotes":
            return [True]
        if action == "addNote":
            return 123456789
        if action == "findNotes":
            return [123456789]
        raise ValueError(f"unsupported action: {action}")

    def create_model(self, params):
        model_name = params.get("modelName")
        if not model_name:
            raise ValueError("missing modelName")
        if model_name in MODELS:
            raise ValueError(f"model already exists: {model_name}")

        fields = params.get("inOrderFields") or []
        if not fields:
            raise ValueError("missing inOrderFields")

        templates = params.get("cardTemplates") or []
        if not templates:
            raise ValueError("missing cardTemplates")

        rendered_templates = {}
        for index, template in enumerate(templates, start=1):
            name = template.get("Name") or f"Card {index}"
            rendered_templates[name] = {
                "Front": template.get("Front", ""),
                "Back": template.get("Back", ""),
            }

        MODELS[model_name] = {
            "fields": list(fields),
            "templates": rendered_templates,
            "css": params.get("css", ".card { font-family: arial; }"),
        }

        return {
            "name": model_name,
            "flds": [{"name": field} for field in fields],
            "tmpls": [{"name": name} for name in rendered_templates],
            "css": MODELS[model_name]["css"],
        }

    @staticmethod
    def require_model(model_name):
        if model_name not in MODELS:
            raise ValueError(f"unknown model: {model_name}")
        return model_name

    def respond(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
