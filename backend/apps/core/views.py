"""Health-check endpoint used by the Flutter client to verify connectivity."""

import logging

from django.db import connection
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

logger = logging.getLogger(__name__)


def _database_is_reachable():
    """Return True when a trivial query against PostgreSQL succeeds."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        return True
    except Exception:
        # The client only ever sees "unavailable"; the detail stays server-side.
        logger.exception("Health check could not reach the database")
        return False


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    """
    GET /api/health/

    Public endpoint. Reports whether the API process is running and whether
    it can reach PostgreSQL, so the mobile app can distinguish "server down"
    from "server up but misconfigured".
    """
    database_ok = _database_is_reachable()

    payload = {
        "status": "ok" if database_ok else "degraded",
        "message": "Hear & Speak Together API is running",
        "database": "connected" if database_ok else "unavailable",
    }

    http_status = (
        status.HTTP_200_OK if database_ok else status.HTTP_503_SERVICE_UNAVAILABLE
    )
    return Response(payload, status=http_status)
