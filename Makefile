.PHONY: all virtualenv install nopyc clean test docs check local validate-release test-downstream upload

SHELL := /usr/bin/env bash
PYTHON_BIN ?= python

all: virtualenv install

virtualenv:
	@if [ ! -d "venv" ]; then \
		$(PYTHON_BIN) -m pip install virtualenv --user; \
		$(PYTHON_BIN) -m virtualenv venv; \
	fi

install: virtualenv
	@( \
		source venv/bin/activate; \
		python -m pip install .; \
	)

nopyc:
	find . -name '*.pyc' | xargs rm -f || true
	find . -name __pycache__ | xargs rm -rf || true

clean: nopyc
	rm -rf build dist *.egg-info venv pyngrok-example-flask

test: virtualenv
	@( \
		source venv/bin/activate; \
		python -m pip install ".[dev]"; \
		coverage run -m unittest discover -v -b; \
		coverage report && coverage xml && coverage html; \
	)

docs: virtualenv
	@( \
		source venv/bin/activate; \
		python -m pip install ".[docs]"; \
		sphinx-build -M html docs build/docs -n; \
	)

check: virtualenv
	@( \
		source venv/bin/activate; \
		python -m pip install ".[dev,docs]"; \
		mypy --strict pyngrok; \
		flake8; \
	)

local:
	@rm -rf *.egg-info dist
	@( \
		$(PYTHON_BIN) -m pip install --upgrade pip; \
        $(PYTHON_BIN) -m pip install --upgrade build; \
		$(PYTHON_BIN) -m build; \
		$(PYTHON_BIN) -m pip install dist/*.tar.gz; \
	)

validate-release:
	@if [[ "${VERSION}" == "" ]]; then echo "VERSION is not set" & exit 1 ; fi

	@if [[ $$(grep "version = \"${VERSION}\"" pyproject.toml) == "" ]] ; then echo "Version not bumped in pyproject.toml" & exit 1 ; fi
	@if [[ $$(grep "__version__ = \"${VERSION}\"" pyngrok/__init__.py) == "" ]] ; then echo "Version not bumped in pyngrok/__init__.py" & exit 1 ; fi

test-downstream:
	@( \
		git clone https://github.com/alexdlaird/pyngrok-example-flask.git; \
		( make -C pyngrok-example-flask install ) || exit $$?; \
		source pyngrok-example-flask/venv/bin/activate; \
		( make local ) || exit $$?; \
		( cd pyngrok-example-flask && pytest -v && cd .. ) || exit $$?; \
		rm -rf pyngrok-example-flask; \
	)

upload: local
	@( \
        $(PYTHON_BIN) -m pip install --upgrade twine; \
		$(PYTHON_BIN) -m build; \
		$(PYTHON_BIN) -m twine upload dist/*; \
	)
