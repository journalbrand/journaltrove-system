module.exports = function(ajv) {
  // Define date-time format validation
  ajv.addFormat("date-time", {
    validate: (dateTimeString) => {
      try {
        const date = new Date(dateTimeString);
        return !isNaN(date.getTime());
      } catch (e) {
        return false;
      }
    }
  });
  return ajv;  // Return the ajv instance
} 