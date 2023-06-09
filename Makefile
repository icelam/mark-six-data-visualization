.PHONY: create-venv clean-venv install install-ci start lint lint-ci first-release release

SRC_FOLDER=web
TEST_FOLDER=tests

# Init new virtual environment
create-venv:
	pipenv --python 3.10.2

# Remove existing virtual environment
clean-venv:
	pipenv --rm

# Install dependencies
install:
	pipenv install --dev

# Install dependencies on CI environment
# Skip lock for cross-platform support
install-ci:
	pipenv install --skip-lock --dev

# Test in virtual environment
start:
	pipenv run streamlit run ${SRC_FOLDER}/main.py

# Run unit test
# test:
# 	pipenv run python -m unittest discover ${TEST_FOLDER}

# Run pylint checking
lint:
	pipenv run pylint ${SRC_FOLDER} ${TEST_FOLDER}

# Run pylint checking on ci
lint-ci:
	( \
		mkdir -p reports; \
		pipenv run pylint ${SRC_FOLDER} ${TEST_FOLDER} --output-format=json --output=reports/pylint.json; \
	)

# Create the first release
first-release:
	npx standard-version --first-release

# Create a new release
release:
	npx standard-version
