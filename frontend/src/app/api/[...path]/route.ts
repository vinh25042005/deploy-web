// Runtime proxy to backend — reads BACKEND_INTERNAL_URL at request time
import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_INTERNAL_URL || 'http://localhost:3001';

export async function GET(req: NextRequest) {
  return proxy(req);
}

export async function POST(req: NextRequest) {
  return proxy(req);
}

export async function PUT(req: NextRequest) {
  return proxy(req);
}

export async function PATCH(req: NextRequest) {
  return proxy(req);
}

export async function DELETE(req: NextRequest) {
  return proxy(req);
}

async function proxy(req: NextRequest) {
  const path = req.nextUrl.pathname.replace('/api', '');
  const url = `${BACKEND_URL}/api${path}${req.nextUrl.search}`;

  try {
    const headers: Record<string, string> = {};
    req.headers.forEach((value, key) => {
      if (!['host', 'connection'].includes(key.toLowerCase())) {
        headers[key] = value;
      }
    });

    const body = ['GET', 'HEAD'].includes(req.method) ? undefined : await req.text();

    const res = await fetch(url, {
      method: req.method,
      headers,
      body,
    });

    const data = await res.text();
    return new NextResponse(data, {
      status: res.status,
      headers: {
        'content-type': res.headers.get('content-type') || 'application/json',
      },
    });
  } catch (error) {
    return NextResponse.json(
      { status: 'error', message: 'Backend unreachable' },
      { status: 502 }
    );
  }
}
