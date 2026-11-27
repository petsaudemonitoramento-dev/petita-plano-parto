-- Additive, restricted educational knowledge base; only approved bundled content is seeded.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5,6,7]
 THEN RAISE EXCEPTION 'isolated homologation with exact migrations 001-007 required'; END IF;
END $$;
SET LOCAL ROLE petita_schema_owner;
CREATE TABLE petita.knowledge_categories (
 name text PRIMARY KEY CHECK(length(btrim(name)) BETWEEN 2 AND 80),
 active boolean NOT NULL DEFAULT true
);
CREATE TABLE petita.knowledge_base (
 id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
 category text NOT NULL REFERENCES petita.knowledge_categories(name),
 question text NOT NULL CHECK(length(btrim(question)) BETWEEN 3 AND 240),
 keywords text[] NOT NULL CHECK(cardinality(keywords) BETWEEN 1 AND 24),
 answer text NOT NULL CHECK(length(btrim(answer)) BETWEEN 10 AND 6000),
 risk_level text NOT NULL DEFAULT 'baixo' CHECK(risk_level IN ('baixo','medio','alto')),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO petita.knowledge_categories(name) VALUES ('Plano de Parto'),('Direitos'),('Apoio'),('Alívio da dor'),('Sinais de atenção'),('Plano final');
INSERT INTO petita.knowledge_base(id,category,question,keywords,answer,risk_level) VALUES
('plano_parto_definicao','Plano de Parto','O que é plano de parto?',ARRAY['plano de parto','o que é','definição','direitos']::text[],'O Plano de Parto é um documento em que a gestante registra suas preferências para o trabalho de parto, parto, pós-parto imediato e cuidados com o bebê. Ele ajuda a equipe de saúde a conhecer seus desejos, sempre considerando a segurança clínica.','baixo'),
('acompanhante','Direitos','Posso ter acompanhante?',ARRAY['acompanhante','parceiro','mãe','familiar','internação']::text[],'Sim. Você pode registrar no plano quem deseja como acompanhante durante a internação, trabalho de parto e parto, conforme organização e normas do serviço de saúde.','baixo'),
('doula','Apoio','Posso ter doula?',ARRAY['doula','apoio','acompanhamento']::text[],'A presença de doula pode ser registrada como preferência, quando o serviço permitir e conforme as regras locais. O app permite indicar esse desejo no plano.','baixo'),
('dor','Alívio da dor','Quais métodos ajudam no alívio da dor?',ARRAY['dor','massagem','banho','respiração','bola','analgesia']::text[],'Podem ser registrados métodos como massagens, técnicas de respiração, banho de chuveiro, bola de parto, movimentação livre e analgesia quando disponível e indicada pela equipe.','baixo'),
('sinais_alerta','Sinais de atenção','Quais sinais são urgentes?',ARRAY['sangramento','dor forte','febre','perda de líquido','pressão alta','dor de cabeça','visão','movimentos do bebê','urgência']::text[],'Sangramento, dor intensa, febre, perda de líquido, falta de ar, convulsão, pressão alta, dor de cabeça forte com alteração visual ou diminuição dos movimentos do bebê são sinais de alerta. Procure imediatamente uma unidade de saúde, maternidade ou emergência.','alto'),
('pdf','Plano final','Consigo gerar PDF do plano?',ARRAY['pdf','baixar','imprimir','compartilhar','plano pronto']::text[],'Sim. Após responder às etapas guiadas pela Petita, o app organiza as informações em um Plano de Parto final e permite gerar um PDF para salvar, imprimir ou compartilhar com a equipe de saúde.','baixo');
ALTER TABLE petita.knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.knowledge_categories FORCE ROW LEVEL SECURITY;
ALTER TABLE petita.knowledge_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.knowledge_base FORCE ROW LEVEL SECURITY;
REVOKE ALL ON petita.knowledge_categories,petita.knowledge_base FROM PUBLIC,petita_runtime;
GRANT SELECT ON petita.knowledge_categories,petita.knowledge_base TO petita_runtime;
GRANT INSERT(name) ON petita.knowledge_categories TO petita_runtime;
GRANT INSERT(category,question,keywords,answer) ON petita.knowledge_base TO petita_runtime;
CREATE POLICY educational_categories_read ON petita.knowledge_categories FOR SELECT TO petita_runtime USING(active);
CREATE POLICY educational_categories_admin_insert ON petita.knowledge_categories FOR INSERT TO petita_runtime WITH CHECK(active AND (SELECT petita_private.is_admin()));
CREATE POLICY educational_knowledge_read ON petita.knowledge_base FOR SELECT TO petita_runtime USING(active AND EXISTS(SELECT FROM petita.knowledge_categories c WHERE c.name=category AND c.active));
CREATE POLICY educational_knowledge_admin_insert ON petita.knowledge_base FOR INSERT TO petita_runtime WITH CHECK(active AND (SELECT petita_private.is_admin()));
INSERT INTO petita_private.schema_migrations(version) VALUES(8);
COMMIT;
