#!/bin/bash

# to run this script, save it as setup.sh and execute it with bash setup.sh
# chmod +x setup.sh
# source setup.sh

# Set project root
PROJECT_ROOT=.

# Create directory structure
mkdir -p $PROJECT_ROOT/data
mkdir -p $PROJECT_ROOT/src
mkdir -p $PROJECT_ROOT/tests
mkdir -p $PROJECT_ROOT/logs
mkdir -p $PROJECT_ROOT/.github/workflows

# Create README.md with starter content
cat > $PROJECT_ROOT/README.md <<EOL
# Template Repo

This is a starter template for Python projects.

## Structure

- \`src/\`: Source code
- \`tests/\`: Unit tests
- \`data/\`: Data files
- \`logs/\`: Log files
EOL

# Create pytest.ini with starter content
cat > $PROJECT_ROOT/pytest.ini <<EOL
[pytest]
testpaths = tests # tells which dir to find tests
python_files = test_*.py # tells pytest the prefix fns
pythonpath = src # either root or your folder structure dir

addopts = -v --tb=short
markers =
    slow: marks tests as slow (deselect with '-m "not slow"')
log_cli_level = INFO
filterwarnings =
    ignore::DeprecationWarning
EOL

# Create src/test/test_main.py with starter test code
cat > $PROJECT_ROOT/tests/test_main.py <<EOL
def test_placeholder():
    assert True
EOL

# Create Rotating JSON Logger
cat > $PROJECT_ROOT/src/logger.py <<EOL
import os
import logging
import logging.handlers
import json
import datetime


def format_json(record):
    """Format log record as simplified JSON string"""
    log_entry = {
        "time": datetime.datetime.fromtimestamp(record.created).isoformat(),
        "logger": record.name,
        "level": record.levelname,
        "message": record.getMessage(),
        "line": record.lineno,
    }
    if record.exc_info:
        log_entry["exception"] = logging._defaultFormatter.formatException(
            record.exc_info
        )
    return json.dumps(log_entry)


def setup_logging():
    """Setup logging with simplified JSON format and file rotation"""
    formatter = logging.Formatter()
    formatter.format = format_json

    log_dir = "./logs"
    os.makedirs(log_dir, exist_ok=True)   # ensure folder exists
    log_file = os.path.join(log_dir, "application.log")

    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=2 * 1024 * 1024, backupCount=1
    )
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    logger = logging.getLogger("json_logger")
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger

# logger = setup_logging()
EOL

# Create GitHub Pull Request Template
cat > $PROJECT_ROOT/.github/pull_request_template.md <<EOL
# Description




## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Chore
EOL

# Create GitHub Actions workflow for CI
cat > $PROJECT_ROOT/.github/workflows/ci.yml <<EOL
name: CI Pipeline
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
jobs:
  quality:
    name: Code Quality
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.13'

    - name: Install quality tools
      run: |
        python -m pip install --upgrade pip
        pip install uv

    - name: Check code quality with ruff
      continue-on-error: true
      run: |
        uv run ruff check src/ tests/ --fix

    - name: Test with pytest
      run: |
        uv run pytest tests/ -v --tb=short
EOL

# Create a .env file
cat > $PROJECT_ROOT/.env <<EOL
# Project environment variables
EOL

# Create src/main.py with starter code
cat > $PROJECT_ROOT/src/main.py <<EOL
from logger import setup_logging
import os
import sys
import time
from utils import duckdb_con_init, ducklake_init, ducklake_attach_minio, ducklake_refresh, schema_creation, execute_SQL_file, update_data
from dotenv import load_dotenv
current_path = os.path.dirname(os.path.abspath(__file__))
parent_path = os.path.abspath(os.path.join(current_path, ".."))
sys.path.append(parent_path)
load_dotenv()

logger = setup_logging()

def db_sync():
    total_start_time = time.time()
    logger.info("Starting database sync")
    data_path = os.path.join(parent_path, "data")
    catalog_path = os.path.join(parent_path, "catalog.ducklake")
    minio_bucket = os.getenv('MINIO_BUCKET_NAME')

    con = duckdb_con_init()
    ducklake_init(con, data_path, catalog_path)
    ducklake_attach_minio(con)
    schema_creation(con)
    update_data(con, logger, minio_bucket, "RAW")
    ducklake_refresh(con)

    staged_queries = [
        'SQL/example_1.sql',
        'SQL/example_2.sql'
    ]

    cleaned_queries = [
        'SQL/example_3.sql',
        'SQL/example_4.sql'
    ]

    execute_SQL_file(con, staged_queries)
    execute_SQL_file(con, cleaned_queries)

    con.close()
    logger.info("Database connection closed")

    total_end_time = time.time()
    logger.info(f"Database sync completed in {total_end_time - total_start_time:.2f} seconds")

if __name__ == "__main__":
    db_sync()
EOL

# Create src/utils with duckdb-specific utility functions
cat > $PROJECT_ROOT/src/utils.py <<EOL
import sys
import os
import io
import duckdb
import polars as pl
current_path = os.path.dirname(os.path.abspath(__file__))
parent_path = os.path.abspath(os.path.join(current_path, ".."))
sys.path.append(parent_path)
from minio import Minio
from logger import setup_logging

logger = setup_logging()

def execute_SQL_file(con, list_of_file_paths):
    for file_path in list_of_file_paths:
        full_path = os.path.join(parent_path, file_path)
        if not os.path.exists(full_path):
            logger.error(f"SQL file not found: {full_path}")
            raise FileNotFoundError(full_path)

    with open(full_path, 'r') as file:
        sql = file.read()
    con.execute(sql)

def duckdb_con_init():
    logger.info("Installing and loading DuckDB extensions")
    duckdb.install_extension("ducklake")
    duckdb.install_extension("httpfs")
    duckdb.load_extension("ducklake")
    duckdb.load_extension("httpfs")
    logger.info("DuckDB extensions loaded successfully")

    con = duckdb.connect(':memory:')
    logger.info(f"Connected to in-memory DuckDB database")
    return con

def ducklake_init(con, data_path, catalog_path):
    logger.info(f"Attaching DuckLake with data path: {data_path}")
    con.execute(f"ATTACH 'ducklake:{catalog_path}' AS my_ducklake (DATA_PATH '{data_path}')")
    con.execute("USE my_ducklake")
    logger.info("DuckLake attached and activated successfully")

def ducklake_attach_minio(con):
    logger.info("Configuring MinIO S3 settings")
    con.execute(f"SET s3_access_key_id = '{os.getenv('MINIO_ACCESS_KEY')}'")
    con.execute(f"SET s3_secret_access_key = '{os.getenv('MINIO_SECRET_KEY')}'")
    con.execute(f"SET s3_endpoint = '{os.getenv('MINIO_EXTERNAL_URL')}'")
    con.execute("SET s3_use_ssl = false")
    con.execute("SET s3_url_style = 'path'")
    logger.info("MinIO S3 configuration completed")

def schema_creation(con):
    logger.info("Creating database schemas")
    con.execute("CREATE SCHEMA IF NOT EXISTS RAW")
    con.execute("CREATE SCHEMA IF NOT EXISTS STAGED")
    con.execute("CREATE SCHEMA IF NOT EXISTS CLEANED")
    logger.info("Database schemas created successfully")

def ducklake_refresh(con): # ensures most up to date .parquet is used
    logger.info("Refreshing DuckLake metadata to most up-to-date")
    con.execute("CALL ducklake_expire_snapshots('my_ducklake', older_than => now())")
    con.execute("CALL ducklake_cleanup_old_files('my_ducklake', cleanup_all => true)")

def update_data(con, logger, bucket_name, folder_path): # inits db & refreshes on data updates
    logger.info("Refreshing database with the most current data")
    file_list_query = f"SELECT * FROM glob('s3://{bucket_name}/{folder_path}/*.parquet')"

    try:
        files_result = con.execute(file_list_query).fetchall()
        file_paths = []
        for row in files_result:
            file_paths.append(row[0])
        
        logger.info(f"Found {len(file_paths)} files in MinIO bucket")
        
        for file_path in file_paths:
            file_name = os.path.basename(file_path).replace('.parquet', '')
            table_name = file_name.upper().replace('-', '_').replace(' ', '_')

            logger.info(f"Processing file: {file_path} -> table: {folder_path}.{table_name}")

            query = f"""
            CREATE OR REPLACE TABLE {folder_path}.{table_name} AS
            SELECT 
                *,
                '{file_name}' AS _source_file,
                CURRENT_TIMESTAMP AS _ingestion_timestamp,
                ROW_NUMBER() OVER () AS _record_id
            FROM read_parquet('{file_path}');
            """
            
            con.execute(query)
            logger.info(f"Successfully created or updated {folder_path}.{table_name}")

    except Exception as e:
        logger.error(f"Error processing files from MinIO: {e}")
        raise


def write_data_to_minio(parquet_buffer, bucket_name, object_name, folder_name=None):
    minio_client = Minio(
        os.getenv("MINIO_EXTERNAL_URL"),
        access_key=os.getenv("MINIO_ACCESS_KEY"),
        secret_key=os.getenv("MINIO_SECRET_KEY"),
        secure=False
    )

    parquet_buffer.seek(0)
    data_bytes = parquet_buffer.read()

    if folder_name:
        folder_name = folder_name.strip("/")
        full_object_name = f"{folder_name}/{object_name}"
    else:
        full_object_name = object_name

    try:
        minio_client.put_object(
            bucket_name,
            full_object_name,
            io.BytesIO(data_bytes),
            length=len(data_bytes),
            content_type="application/x-parquet",
        )
        logger.info(f"Successfully wrote {full_object_name} to bucket {bucket_name}")
    except Exception as e:
        logger.error(f"Failed to write data to MinIO: {e}")
EOL

# Create .gitignore with common Python ignores
cat > $PROJECT_ROOT/.gitignore <<EOL
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[codz]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py.cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
#   For a library or package, you might want to ignore these files since the code is
#   intended to run in multiple environments; otherwise, check them in:
# .python-version

# pipenv
#   According to pypa/pipenv#598, it is recommended to include Pipfile.lock in version control.
#   However, in case of collaboration, if having platform-specific dependencies or dependencies
#   having no cross-platform support, pipenv may install dependencies that don't work, or not
#   install all needed dependencies.
#Pipfile.lock

# UV
#   Similar to Pipfile.lock, it is generally recommended to include uv.lock in version control.
#   This is especially recommended for binary packages to ensure reproducibility, and is more
#   commonly ignored for libraries.
uv.lock

# poetry
#   Similar to Pipfile.lock, it is generally recommended to include poetry.lock in version control.
#   This is especially recommended for binary packages to ensure reproducibility, and is more
#   commonly ignored for libraries.
#   https://python-poetry.org/docs/basic-usage/#commit-your-poetrylock-file-to-version-control
#poetry.lock
#poetry.toml

# pdm
#   Similar to Pipfile.lock, it is generally recommended to include pdm.lock in version control.
#   pdm recommends including project-wide configuration in pdm.toml, but excluding .pdm-python.
#   https://pdm-project.org/en/latest/usage/project/#working-with-version-control
#pdm.lock
#pdm.toml
.pdm-python
.pdm-build/

# pixi
#   Similar to Pipfile.lock, it is generally recommended to include pixi.lock in version control.
#pixi.lock
#   Pixi creates a virtual environment in the .pixi directory, just like venv module creates one
#   in the .venv directory. It is recommended not to include this directory in version control.
.pixi

# PEP 582; used by e.g. github.com/David-OConnor/pyflow and github.com/pdm-project/pdm
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.envrc
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyCharm
#  JetBrains specific template is maintained in a separate JetBrains.gitignore that can
#  be found at https://github.com/github/gitignore/blob/main/Global/JetBrains.gitignore
#  and can be added to the global gitignore or merged into this file.  For a more nuclear
#  option (not recommended) you can uncomment the following to ignore the entire idea folder.
#.idea/

# Abstra
# Abstra is an AI-powered process automation framework.
# Ignore directories containing user credentials, local state, and settings.
# Learn more at https://abstra.io/docs
.abstra/

# Visual Studio Code
#  Visual Studio Code specific template is maintained in a separate VisualStudioCode.gitignore 
#  that can be found at https://github.com/github/gitignore/blob/main/Global/VisualStudioCode.gitignore
#  and can be added to the global gitignore or merged into this file. However, if you prefer, 
#  you could uncomment the following to ignore the entire vscode folder
# .vscode/

# Ruff stuff:
.ruff_cache/

# PyPI configuration file
.pypirc

# Marimo
marimo/_static/
marimo/_lsp/
__marimo__/

# Streamlit
.streamlit/secrets.toml

.DS_Store
/data
*.catalog
*.db
EOL

# Create sql/query.sql with starter content
cat > $PROJECT_ROOT/sql/query.sql <<EOL
-- SQL queries go here
-- Example query:
-- SELECT * FROM my_table WHERE condition = 'value';
EOL

# Set up virtual environment & package manager
cd $PROJECT_ROOT
python3 -m uv init

rm main.py

uv add pytest ruff dotenv duckdb polars minio

source .venv/bin/activate

git branch -m master main

git add .

git commit -m "Setup Project & Boilerplate"

echo "Setup process completed."
