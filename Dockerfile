FROM cgr.dev/chainguard/wolfi-base AS base

EXPOSE 8100

USER root

ARG PYTHON_VERSION=3.9.9

RUN apk add \
    wget \
    gcc \
    make \
    zlib-dev \
    libffi-dev \
    openssl-dev \
    glibc-dev \
    git

# download and extract python sources
RUN cd /opt \
    && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \                                              
    && tar xzf Python-${PYTHON_VERSION}.tgz

# build python and remove left-over sources
RUN cd /opt/Python-${PYTHON_VERSION} \ 
    && ./configure --prefix=/usr --enable-optimizations --with-ensurepip=install \
    && make install \
    && rm /opt/Python-${PYTHON_VERSION}.tgz /opt/Python-${PYTHON_VERSION} -rf

# Set up a virtual environment
RUN python3 -m venv /venv && \
    /venv/bin/pip install --upgrade pip
ENV PATH="/venv/bin:$PATH"

# Use a separate build stage for installing Python dependencies
FROM base AS dependencies

# Install pipenv
RUN pip install pipenv
COPY --from=base ./venv /venv

# Copy only the Pipfile and Pipfile.lock
COPY ./Pipfile ./Pipfile.lock ./

# Use secrets to install packages from a private repository
RUN . /venv/bin/activate && \
    pipenv install --ignore-pipfile

# Final stage for running the application
FROM base AS runtime

# Use base image user
USER 65532:65532

# Copy the application code
COPY --chown=65532:65532 ./app /app
COPY --from=dependencies --chown=65532:65532 ./venv /venv

# Set environment variables
ENV PYTHONPATH="${PYTHONPATH}:/venv/bin"
ENV PATH="/venv/bin:$PATH"

ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100"]