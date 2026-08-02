const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const factoryRepository = require('../repositories/factoryRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  res.render('factories/index', { title: 'Pabrik', factories: await factoryRepository.listFactories(req.supabase) });
}));
router.get('/new', (req, res) => res.render('factories/form', { title: 'Tambah Pabrik', factory: null }));
router.post('/', asyncHandler(async (req, res) => {
  const factory = await factoryRepository.createFactory(req.supabase, req.body);
  req.flash('success', 'Pabrik berhasil disimpan.');
  res.redirect(`/factories/${factory.id}`);
}));
router.get('/:id', asyncHandler(async (req, res) => {
  const factory = await factoryRepository.getFactory(req.supabase, req.params.id);
  res.render('factories/show', { title: factory.name, factory });
}));
router.get('/:id/edit', asyncHandler(async (req, res) => {
  const factory = await factoryRepository.getFactory(req.supabase, req.params.id);
  res.render('factories/form', { title: 'Edit Pabrik', factory });
}));
router.put('/:id', asyncHandler(async (req, res) => {
  await factoryRepository.updateFactory(req.supabase, req.params.id, req.body);
  req.flash('success', 'Pabrik berhasil diperbarui.');
  res.redirect(`/factories/${req.params.id}`);
}));
router.delete('/:id', asyncHandler(async (req, res) => {
  await factoryRepository.deleteFactory(req.supabase, req.params.id);
  req.flash('success', 'Pabrik berhasil dihapus.');
  res.redirect('/factories');
}));

module.exports = router;
