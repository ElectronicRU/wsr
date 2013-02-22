
encodings: encodings.json
	python flatten_encodings.py < encodings.json > encodings

encodings.json:
	curl http://encoding.spec.whatwg.org/encodings.json > encodings.json


