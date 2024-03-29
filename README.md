# Mark Six Data Visualization

Mark Six, a lottery game organised by the Hong Kong Jockey Club. This repository contains automatic updated data of Mark Six results, and display them in Streamlit.

## How data is updated
The data automatically updated using GitHub actions everyday at 10:00 pm (Hong Kong Time), and committed to repository whenever there is any changes on data.

## How to run Streamlit to visualize historical data

### Prerequisite

1. Python 3 installed
2. pipenv installed

### 1. Setting up virtual environment

```bash
pipenv --python 3.10.2
```

### 2. Installing dependencies

```bash
pipenv install --skip-lock --dev
```

### 3. Starting Streamlit

```bash
pipenv run streamlit run web/main.py
```

## Special Thanks
Special thanks to [@tonberry22](https://github.com/tonberry22) for his generous help with completing the code for this project.
