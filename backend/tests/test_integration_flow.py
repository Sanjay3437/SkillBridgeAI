"""End-to-end integration test of the core user journey."""

from tests.conftest import auth_headers, make_pdf, register, wait_for_status

RESUME_TEXT = """Jane Doe - Software Engineer
Built a React dashboard used by 2,000 customers.
Designed REST APIs with FastAPI and PostgreSQL.
Containerized services with Docker and deployed via GitHub Actions.
"""

JOB_TEXT = """We are hiring a backend engineer.
Required: Python, FastAPI, PostgreSQL, Docker.
Preferred: Kubernetes and React.
You will build REST APIs and deploy services with CI/CD.
"""


async def _create_processed_resume(client, headers) -> dict:
    pdf = make_pdf(RESUME_TEXT)
    response = await client.post(
        "/api/v1/resumes",
        headers=headers,
        files={"file": ("resume.pdf", pdf, "application/pdf")},
    )
    assert response.status_code == 202, response.text
    resume_id = response.json()["id"]
    return await wait_for_status(client, f"/api/v1/resumes/{resume_id}", headers)


async def _create_processed_job(client, headers) -> dict:
    response = await client.post(
        "/api/v1/jobs",
        headers=headers,
        json={"title": "Backend Engineer", "company": "Acme", "description": JOB_TEXT},
    )
    assert response.status_code == 202, response.text
    job_id = response.json()["id"]
    return await wait_for_status(client, f"/api/v1/jobs/{job_id}", headers)


async def test_invalid_pdf_is_rejected(client):
    data = await register(client)
    response = await client.post(
        "/api/v1/resumes",
        headers=auth_headers(data),
        files={"file": ("resume.pdf", b"not a pdf", "application/pdf")},
    )
    assert response.status_code == 422


async def test_resume_upload_extracts_skills(client):
    data = await register(client)
    resume = await _create_processed_resume(client, auth_headers(data))

    assert resume["status"] == "completed"
    skill_names = {skill["skill"] for skill in resume["skills"]}
    assert {"React", "FastAPI", "PostgreSQL", "Docker"} <= skill_names
    for skill in resume["skills"]:
        assert skill["evidence"]


async def test_full_analysis_and_roadmap_flow(client):
    data = await register(client)
    headers = auth_headers(data)

    resume = await _create_processed_resume(client, headers)
    job = await _create_processed_job(client, headers)
    assert job["status"] == "completed"
    assert any(skill["skill"] == "Kubernetes" for skill in job["skills"])

    analysis_response = await client.post(
        "/api/v1/analyses",
        headers=headers,
        json={"resume_id": resume["id"], "job_id": job["id"]},
    )
    assert analysis_response.status_code == 202, analysis_response.text
    analysis_id = analysis_response.json()["id"]

    analysis = await wait_for_status(client, f"/api/v1/analyses/{analysis_id}", headers)
    assert analysis["status"] == "completed"
    assert analysis["coverage"] is not None
    assert analysis["coverage"]["percentage"] is not None
    matched_names = {skill["skill"] for skill in analysis["matched_skills"]}
    assert {"FastAPI", "PostgreSQL", "Docker"} <= matched_names
    # Related experience is surfaced separately and never counted as matched.
    related_names = {skill["skill"] for skill in analysis["related_skills"]}
    assert "Kubernetes" in related_names  # via Docker
    assert "Python" in related_names  # via FastAPI

    # The roadmap is only available after generation; GET must not create it.
    missing = await client.get(f"/api/v1/analyses/{analysis_id}/roadmap", headers=headers)
    assert missing.status_code == 404

    roadmap_response = await client.post(
        f"/api/v1/analyses/{analysis_id}/roadmap", headers=headers
    )
    assert roadmap_response.status_code == 201, roadmap_response.text
    roadmap = roadmap_response.json()
    assert roadmap["tasks"]
    assert all(task["resource_url"].startswith("http") for task in roadmap["tasks"])

    fetched = await client.get(f"/api/v1/analyses/{analysis_id}/roadmap", headers=headers)
    assert fetched.status_code == 200
    assert [task["id"] for task in fetched.json()["tasks"]] == [
        task["id"] for task in roadmap["tasks"]
    ]

    repeated = await client.post(f"/api/v1/analyses/{analysis_id}/roadmap", headers=headers)
    assert repeated.status_code == 201
    assert repeated.json()["id"] == roadmap["id"]

    task_id = roadmap["tasks"][0]["id"]
    patch = await client.patch(
        f"/api/v1/roadmap-tasks/{task_id}", headers=headers, json={"status": "completed"}
    )
    assert patch.status_code == 200
    assert patch.json()["status"] == "completed"

    dashboard = await client.get("/api/v1/dashboard", headers=headers)
    assert dashboard.status_code == 200
    summary = dashboard.json()
    assert summary["resumes"] == 1
    assert summary["jobs"] == 1
    assert summary["analyses"] == 1
    assert summary["tasks_completed"] >= 1


async def test_users_cannot_access_other_users_resources(client):
    first = await register(client, email="first@example.com")
    second = await register(client, email="second@example.com")

    resume = await _create_processed_resume(client, auth_headers(first))

    response = await client.get(
        f"/api/v1/resumes/{resume['id']}", headers=auth_headers(second)
    )
    assert response.status_code == 404

    analysis = await client.get(
        f"/api/v1/analyses/{resume['id']}", headers=auth_headers(second)
    )
    assert analysis.status_code == 404


async def test_analysis_requires_completed_inputs(client):
    data = await register(client)
    headers = auth_headers(data)

    response = await client.post(
        "/api/v1/analyses",
        headers=headers,
        json={
            "resume_id": "4f30c59c-34a6-4a0b-8f71-8a76cb9e8741",
            "job_id": "e691ca30-4ad8-4875-a00a-23cb645be315",
        },
    )
    assert response.status_code == 422
