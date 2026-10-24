'use strict';

// To base a failed-delivery due on items only, use order.items_subtotal_minor here.
const DUE_POLICY = Object.freeze({
  amountMinor: (order) => order.total_minor,
});

module.exports = { DUE_POLICY };
