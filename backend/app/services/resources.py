"""Curated, verified learning resources. The LLM never invents URLs."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Resource:
    title: str
    url: str
    steps: tuple[str, ...]


# Keyed by taxonomy skill id. Fallback below covers anything not listed.
RESOURCES: dict[str, Resource] = {
    "docker": Resource(
        "Docker Fundamentals",
        "https://docs.docker.com/get-started/",
        (
            "Understand images, containers, and volumes",
            "Write a Dockerfile for a small FastAPI service",
            "Run the service with Docker Compose",
        ),
    ),
    "kubernetes": Resource(
        "Kubernetes Basics",
        "https://kubernetes.io/docs/tutorials/kubernetes-basics/",
        (
            "Learn pods, deployments, and services",
            "Deploy a container to a local cluster (kind/minikube)",
            "Expose it with a Service and inspect with kubectl",
        ),
    ),
    "ci-cd": Resource(
        "CI/CD with GitHub Actions",
        "https://docs.github.com/en/actions",
        (
            "Create a workflow that runs tests on push",
            "Add lint and build checks",
            "Deploy automatically on merge to main",
        ),
    ),
    "github-actions": Resource(
        "GitHub Actions Quickstart",
        "https://docs.github.com/en/actions/quickstart",
        (
            "Create your first workflow file",
            "Cache dependencies between runs",
            "Add a status badge to the README",
        ),
    ),
    "postgresql": Resource(
        "PostgreSQL Tutorial",
        "https://www.postgresql.org/docs/current/tutorial.html",
        (
            "Model tables with primary and foreign keys",
            "Write joins and aggregate queries",
            "Add indexes and read EXPLAIN plans",
        ),
    ),
    "sqlalchemy": Resource(
        "SQLAlchemy 2.0 ORM",
        "https://docs.sqlalchemy.org/en/20/orm/",
        (
            "Define models with Mapped types",
            "Use async sessions in a service layer",
            "Add Alembic migrations",
        ),
    ),
    "fastapi": Resource(
        "FastAPI Tutorial",
        "https://fastapi.tiangolo.com/tutorial/",
        (
            "Build typed routes with Pydantic v2",
            "Add dependency injection and auth",
            "Document and test the OpenAPI schema",
        ),
    ),
    "react": Resource(
        "React Learn",
        "https://react.dev/learn",
        (
            "Build components with props and state",
            "Manage side effects with hooks",
            "Split logic into custom hooks",
        ),
    ),
    "typescript": Resource(
        "TypeScript Handbook",
        "https://www.typescriptlang.org/docs/handbook/intro.html",
        (
            "Type functions, objects, and unions",
            "Use generics for reusable code",
            "Enable strict mode and fix type errors",
        ),
    ),
    "flutter": Resource(
        "Flutter Codelabs",
        "https://docs.flutter.dev/get-started/codelab",
        (
            "Build a multi-screen app with navigation",
            "Manage state with Riverpod",
            "Write widget tests",
        ),
    ),
    "python": Resource(
        "Python Tutorial",
        "https://docs.python.org/3/tutorial/",
        (
            "Practice data structures and comprehensions",
            "Use typing and dataclasses",
            "Write tests with pytest",
        ),
    ),
    "machine-learning": Resource(
        "scikit-learn User Guide",
        "https://scikit-learn.org/stable/user_guide.html",
        (
            "Frame a supervised learning problem",
            "Train and validate a baseline model",
            "Evaluate with precision, recall, and F1",
        ),
    ),
    "llm": Resource(
        "OpenAI API Documentation",
        "https://platform.openai.com/docs",
        (
            "Call a chat completion with structured output",
            "Validate responses with Pydantic",
            "Add retries, timeouts, and cost tracking",
        ),
    ),
    "rag": Resource(
        "RAG from scratch",
        "https://github.com/langchain-ai/rag-from-scratch",
        (
            "Chunk and embed a document set",
            "Store vectors in pgvector",
            "Evaluate retrieval quality",
        ),
    ),
    "embeddings": Resource(
        "Sentence Transformers",
        "https://www.sbert.net/",
        (
            "Encode text into vectors",
            "Compute cosine similarity",
            "Tune thresholds on labeled pairs",
        ),
    ),
    "git": Resource(
        "Pro Git",
        "https://git-scm.com/book/en/v2",
        (
            "Practice branching and rebasing",
            "Write meaningful commit messages",
            "Resolve a merge conflict",
        ),
    ),
    "testing": Resource(
        "pytest Documentation",
        "https://docs.pytest.org/en/stable/",
        (
            "Write unit tests with fixtures",
            "Test async code",
            "Add coverage reporting to CI",
        ),
    ),
    "rest-api": Resource(
        "HTTP API Design",
        "https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design",
        (
            "Design resource-oriented endpoints",
            "Use status codes and pagination",
            "Version and document the API",
        ),
    ),
    "system-design": Resource(
        "System Design Primer",
        "https://github.com/donnemartin/system-design-primer",
        (
            "Estimate capacity and storage",
            "Choose caching and database strategies",
            "Explain trade-offs in a design review",
        ),
    ),
    "aws": Resource(
        "AWS Skill Builder",
        "https://skillbuilder.aws/",
        (
            "Learn core compute, storage, and IAM",
            "Deploy a small service",
            "Add logging and billing alarms",
        ),
    ),
    "security": Resource(
        "OWASP Top 10",
        "https://owasp.org/www-project-top-ten/",
        (
            "Review injection and auth risks",
            "Add input validation and rate limits",
            "Run a dependency audit",
        ),
    ),
    "jwt": Resource(
        "JWT Introduction",
        "https://jwt.io/introduction",
        (
            "Understand claims and signing",
            "Implement access and refresh tokens",
            "Handle revocation and expiry",
        ),
    ),
    "oauth": Resource(
        "OAuth 2.0 Simplified",
        "https://www.oauth.com/",
        (
            "Learn the authorization code flow",
            "Integrate a provider in a test app",
            "Store tokens securely on mobile",
        ),
    ),
    "mongodb": Resource(
        "MongoDB University",
        "https://learn.mongodb.com/",
        (
            "Model documents for access patterns",
            "Write queries and aggregations",
            "Add indexes and monitor performance",
        ),
    ),
    "redis": Resource(
        "Redis University",
        "https://university.redis.io/",
        (
            "Use strings, hashes, and sorted sets",
            "Add caching with expiry",
            "Inspect latency with redis-cli",
        ),
    ),
    "graphql": Resource(
        "GraphQL Learn",
        "https://graphql.org/learn/",
        (
            "Define a schema and resolvers",
            "Handle pagination and errors",
            "Secure queries with depth limits",
        ),
    ),
    "microservices": Resource(
        "Microservices Patterns",
        "https://microservices.io/patterns/",
        (
            "Split a service along a domain boundary",
            "Add an API gateway and retries",
            "Instrument tracing and health checks",
        ),
    ),
    "pytorch": Resource(
        "PyTorch Tutorials",
        "https://pytorch.org/tutorials/",
        (
            "Build a small neural network",
            "Train with a data loader",
            "Evaluate and save the model",
        ),
    ),
    "pandas": Resource(
        "pandas User Guide",
        "https://pandas.pydata.org/docs/user_guide/",
        (
            "Load and clean a dataset",
            "Group, merge, and reshape",
            "Profile missing data",
        ),
    ),
}


def get_resource(skill_id: str, skill_name: str) -> Resource:
    if skill_id in RESOURCES:
        return RESOURCES[skill_id]
    return Resource(
        title=f"Learn {skill_name}",
        url=f"https://developer.mozilla.org/en-US/search?q={skill_name.replace(' ', '+')}",
        steps=(
            f"Read the official {skill_name} documentation",
            f"Build a small project that uses {skill_name}",
            f"Write notes on {skill_name} trade-offs and pitfalls",
        ),
    )


__all__ = ["RESOURCES", "Resource", "get_resource"]
