import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import admin from 'firebase-admin';
import cron from 'node-cron';
import twilio from 'twilio';

const app = express();
app.use(express.json());
app.use(cors({ origin: true }));
app.use(helmet());
app.use(morgan('dev'));

// Firebase Admin init
if (!admin.apps.length) {
  let appInit = null;
  try {
    const svc = process.env.FIREBASE_SERVICE_ACCOUNT
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      : null;
    if (svc) {
      appInit = admin.initializeApp({
        credential: admin.credential.cert(svc),
        projectId: process.env.FIREBASE_PROJECT_ID
      });
    } else {
      appInit = admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID
      });
    }
  } catch (e) {
    console.error('Firebase Admin init failed:', e.message);
  }
}
const db = admin.firestore();

// Twilio
const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const TWILIO_FROM = process.env.TWILIO_PHONE_NUMBER;

// Auth middleware
async function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

async function getUserDoc(uid) {
  const doc = await db.collection('users').doc(uid).get();
  return doc.exists ? { id: doc.id, ...doc.data() } : null;
}

function requireRole(role) {
  return async (req, res, next) => {
    const profile = await getUserDoc(req.user.uid);
    if (!profile || profile.role !== role) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    req.profile = profile;
    next();
  };
}

// Users
app.post('/api/users', authMiddleware, async (req, res) => {
  const { name, phone, role } = req.body;
  if (!role || !['manager','employee'].includes(role)) {
    return res.status(400).json({ error: 'role must be manager|employee' });
  }
  const data = {
    name: name || null,
    phone: phone || null,
    role,
    email: req.user.email || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  await db.collection('users').doc(req.user.uid).set(data, { merge: true });
  return res.json({ ok: true });
});

app.get('/api/users', authMiddleware, requireRole('manager'), async (req, res) => {
  const snap = await db.collection('users').where('role','==','employee').get();
  return res.json(snap.docs.map(d => ({ id: d.id, ...d.data() })));
});

// Tasks
app.post('/api/tasks', authMiddleware, requireRole('manager'), async (req, res) => {
  const { title, description, assignedTo, dueDate } = req.body;
  if (!title || !assignedTo) return res.status(400).json({ error: 'title and assignedTo required' });
  const now = admin.firestore.FieldValue.serverTimestamp();
  const ref = await db.collection('tasks').add({
    title,
    description: description || '',
    assignedTo,
    assignedBy: req.user.uid,
    status: 'pending',
    createdAt: now,
    updatedAt: now,
    dueDate: dueDate ? new Date(dueDate) : null,
    lastEmployeeUpdateAt: null
  });
  return res.json({ id: ref.id });
});

app.get('/api/tasks', authMiddleware, async (req, res) => {
  const profile = await getUserDoc(req.user.uid);
  let q = db.collection('tasks');
  if (profile?.role === 'employee') {
    q = q.where('assignedTo','==', req.user.uid);
  }
  const snap = await q.orderBy('createdAt','desc').get();
  return res.json(snap.docs.map(d => ({ id: d.id, ...d.data() })));
});

app.patch('/api/tasks/:id', authMiddleware, async (req, res) => {
  const { status, title, description, dueDate } = req.body;
  const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (status) updates.status = status;
  if (title) updates.title = title;
  if (description) updates.description = description;
  if (dueDate !== undefined) updates.dueDate = dueDate ? new Date(dueDate) : null;
  await db.collection('tasks').doc(req.params.id).set(updates, { merge: true });
  return res.json({ ok: true });
});

app.post('/api/tasks/:id/updates', authMiddleware, async (req, res) => {
  const { message, status } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });
  const now = admin.firestore.FieldValue.serverTimestamp();
  const taskRef = db.collection('tasks').doc(req.params.id);
  await taskRef.collection('updates').add({ by: req.user.uid, message, status: status || null, createdAt: now });
  const merge = { lastEmployeeUpdateAt: now, updatedAt: now };
  if (status) merge.status = status;
  await taskRef.set(merge, { merge: true });
  return res.json({ ok: true });
});

app.post('/api/sms/test', authMiddleware, async (req, res) => {
  const { to, body } = req.body;
  if (!to || !body) return res.status(400).json({ error: 'to & body required' });
  try {
    const msg = await twilioClient.messages.create({ from: TWILIO_FROM, to, body });
    return res.json({ sid: msg.sid });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// Cron job for daily reminders
const cronTz = process.env.CRON_TZ || 'Asia/Kolkata';
const hour = parseInt(process.env.DAILY_SMS_HOUR || '18', 10); // 24h
const cronExpr = `0 ${hour} * * *`;
cron.schedule(cronExpr, async () => {
  console.log('Running daily reminder cron...');
  try {
    const today = new Date();
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const employees = await db.collection('users').where('role','==','employee').get();
    for (const d of employees.docs) {
      const emp = { id: d.id, ...d.data() };
      if (!emp.phone) continue;
      const tasksSnap = await db.collection('tasks').where('assignedTo','==', emp.id).get();
      let hasUpdateToday = false;
      for (const t of tasksSnap.docs) {
        const last = t.get('lastEmployeeUpdateAt');
        if (last && last.toDate() >= start) { hasUpdateToday = true; break; }
      }
      if (!hasUpdateToday) {
        await twilioClient.messages.create({
          from: TWILIO_FROM,
          to: emp.phone,
          body: 'Reminder: Please submit your daily task updates in TaskFlow.'
        });
        console.log('SMS sent:', emp.phone);
      }
    }
  } catch (e) {
    console.error('Cron error:', e.message);
  }
}, { timezone: cronTz });

app.get('/', (_, res) => res.send('TaskFlow backend running'));
const port = process.env.PORT || 8080;
app.listen(port, () => console.log('Server listening on', port));
