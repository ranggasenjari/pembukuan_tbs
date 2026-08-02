const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const relationAgentRepository = require('../repositories/relationAgentRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { q: req.query.q };
  const relationAgents = await relationAgentRepository.listRelationAgents(req.supabase, filters);
  res.render('relation-agents/index', { title: 'Relasi / Agen', relationAgents, filters });
}));

router.get('/new', (req, res) => {
  res.render('relation-agents/form', { title: 'Tambah Relasi / Agen', relationAgent: null });
});

router.post('/', asyncHandler(async (req, res) => {
  const relationAgent = await relationAgentRepository.createRelationAgent(req.supabase, req.body);
  req.flash('success', 'Relasi / Agen berhasil disimpan.');
  res.redirect(`/relation-agents/${relationAgent.id}`);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const relationAgent = await relationAgentRepository.getRelationAgent(req.supabase, req.params.id);
  res.render('relation-agents/show', { title: relationAgent.name, relationAgent });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const relationAgent = await relationAgentRepository.getRelationAgent(req.supabase, req.params.id);
  res.render('relation-agents/form', { title: 'Edit Relasi / Agen', relationAgent });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await relationAgentRepository.updateRelationAgent(req.supabase, req.params.id, req.body);
  req.flash('success', 'Relasi / Agen berhasil diperbarui.');
  res.redirect(`/relation-agents/${req.params.id}`);
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await relationAgentRepository.deleteRelationAgent(req.supabase, req.params.id);
  req.flash('success', 'Relasi / Agen berhasil dihapus.');
  res.redirect('/relation-agents');
}));

module.exports = router;
