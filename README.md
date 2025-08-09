# Data Engineering Pipeline Scripts

This repository contains a collection of shell scripts designed to quickly spin up projects in various paradigms of data engineering architecture. These scripts aim to streamline the setup process for different architectural approaches, enabling rapid prototyping and deployment.

## Scripts Overview

- **legacy.sh**: Sets up a project following legacy data engineering practices, focusing on ETL solutions and smaller batch processing jobs.
- **mid-modern.sh**: Configures a project with a contemporary approach, integrating modern ELT practices with dbt and orchestration with prefect.
- **neutral-uv.sh**: Creates a neutral architecture setup, emphasizing vendor-agnostic and universally applicable solutions. Designed for flexibility and adaptability across different environments.
- **ultra-modern.sh**: Establishes a cutting-edge data engineering project, leveraging the latest technologies and a data lake house approach with DuckDb and Ducklake.

## Purpose

The purpose of these scripts is to provide a quick and efficient way to spin up projects in various data engineering paradigms. Whether you are working with legacy systems, transitioning to modern solutions, or building state-of-the-art pipelines, these scripts serve as a starting point for your projects.

Feel free to explore the scripts and adapt them to your specific needs.

## How To Use

The scripts are designed to be run from the command line. To use a script, simply execute it with the commented section at the top. For example:

```bash
chmod +x setup.sh
source setup.sh
```

This will initiate the setup process for a new project using uv as the package manager, ruff for code linting & formatting, pytest for testing, and the paradigm skeleton of the chosen paradigm (with my preferred toolsets). These scripts are untested for Windows environments, so adjustments may be necessary for compatibility.