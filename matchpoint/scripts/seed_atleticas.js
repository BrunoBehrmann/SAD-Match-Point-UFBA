// Seed script — popula a coleção "atleticas" no Firestore
//
// Como usar:
//   1. Acesse Firebase Console → Project Settings → Service accounts
//   2. Clique em "Generate new private key" e salve o arquivo como
//      "serviceAccountKey.json" nesta mesma pasta (scripts/)
//   3. No terminal, dentro desta pasta:
//        npm install
//        node seed_atleticas.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const atleticas = [
  { nome: 'Pitbulls',     curso: 'ADMINISTRAÇÃO/SECRETARIADO' },
  { nome: 'Esquadrão',    curso: 'ARQUITETURA' },
  { nome: 'Malvadona',    curso: 'ARQUIVOLOGIA' },
  { nome: 'Imperium',     curso: 'ARTES UNIFICADA' },
  { nome: 'Atletihac',    curso: 'B.IS' },
  { nome: 'Neurótica',    curso: 'CIÊNCIAS CONTÁBEIS' },
  { nome: 'Tio Patinhas', curso: 'CIÊNCIAS ECONÔMICAS' },
  { nome: 'Athena',       curso: 'COMUNICAÇÃO' },
  { nome: 'Federal',      curso: 'DIREITO' },
  { nome: 'Jaguar',       curso: 'EDUCAÇÃO FÍSICA' },
  { nome: 'Venenosa',     curso: 'ENFERMAGEM' },
  { nome: 'Manada',       curso: 'ENGENHARIA CIVIL' },
  { nome: 'Bulls',        curso: 'ENGENHARIA MECÂNICA' },
  { nome: 'Magistral',    curso: 'FARMÁCIA' },
  { nome: 'Traumática',   curso: 'FISIOTERAPIA' },
  { nome: 'Malagueta',    curso: 'GASTRONOMIA' },
  { nome: 'Avalanche',    curso: 'GEOCIÊNCIAS' },
  { nome: 'Flama',        curso: 'HISTÓRIA' },
  { nome: 'Matilha',      curso: 'ICTI' },
  { nome: 'Pinguçu',      curso: 'IME, IC' },
  { nome: 'Letais',       curso: 'LETRAS' },
  { nome: 'Carcará',      curso: 'MEDICINA' },
  { nome: 'Komodo',       curso: 'MEDICINA VETERINÁRIA' },
  { nome: 'Cabulosa',     curso: 'NUTRIÇÃO' },
  { nome: 'Sharks',       curso: 'ODONTOLOGIA' },
  { nome: 'Apollo',       curso: 'POLITÉCNICA' },
  { nome: 'Reativa',      curso: 'QUÍMICA' },
  { nome: 'Brutal',       curso: 'SÃO LÁZARO' },
  { nome: 'Serpentes',    curso: 'TERAPIA OCUPACIONAL' },
  { nome: 'Ferroada',     curso: 'ZOOTECNIA' },
];

async function seed() {
  // Atlética sentinel com ID fixo — usada quando usuário não tem atlética
  await db.collection('atleticas').doc('sem-atletica').set({
    nome: 'Sem Atlética',
    curso: '',
    gradeHoraria: [],
    faltasConsecutivas: 0,
    gestoresIds: [],
    codigoGestor: '',
  });

  const batch = db.batch();
  for (const atletica of atleticas) {
    const ref = db.collection('atleticas').doc();
    batch.set(ref, {
      nome: atletica.nome,
      curso: atletica.curso,
      gradeHoraria: [],
      faltasConsecutivas: 0,
      gestoresIds: [],
      codigoGestor: '',
    });
  }

  await batch.commit();
  console.log(`✅ ${atleticas.length + 1} atléticas inseridas (30 reais + sentinel).`);
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Erro:', err);
  process.exit(1);
});
