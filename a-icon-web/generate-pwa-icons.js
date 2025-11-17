#!/usr/bin/env node

/**
 * Generate PWA icons from the logo PNG
 * This script creates all required icon sizes for PWA installation
 *
 * Run from project root: node a-icon-web/generate-pwa-icons.js
 * Or install sharp in a-icon-web: cd a-icon-web && npm install sharp --save-dev
 */

const fs = require('fs');
const path = require('path');

// Try to load sharp from different locations
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  try {
    sharp = require('../a-icon-api/node_modules/sharp');
  } catch (e2) {
    console.error('❌ Error: Sharp is not installed.');
    console.error('Please run: cd a-icon-api && npm install');
    console.error('Or run this script from the a-icon-api directory with: node ../a-icon-web/generate-pwa-icons.js');
    process.exit(1);
  }
}

const INPUT_IMAGE = path.join(__dirname, 'public', 'assets', 'images', 'logo-png.png');
const OUTPUT_DIR = path.join(__dirname, 'public', 'assets', 'icons');

// Icon sizes needed for PWA
const ICON_SIZES = [
  // Standard PWA sizes
  { size: 72, name: 'icon-72x72.png' },
  { size: 96, name: 'icon-96x96.png' },
  { size: 128, name: 'icon-128x128.png' },
  { size: 144, name: 'icon-144x144.png' },
  { size: 152, name: 'icon-152x152.png' },
  { size: 192, name: 'icon-192x192.png' },
  { size: 384, name: 'icon-384x384.png' },
  { size: 512, name: 'icon-512x512.png' },
  
  // Apple Touch Icons
  { size: 57, name: 'icon-57x57.png' },
  { size: 60, name: 'icon-60x60.png' },
  { size: 76, name: 'icon-76x76.png' },
  { size: 114, name: 'icon-114x114.png' },
  { size: 120, name: 'icon-120x120.png' },
  { size: 180, name: 'apple-touch-icon.png' },
];

// Maskable icons (with safe zone padding)
const MASKABLE_SIZES = [
  { size: 192, name: 'icon-192x192-maskable.png' },
  { size: 512, name: 'icon-512x512-maskable.png' },
];

async function generateIcons() {
  console.log('🎨 Generating PWA icons...\n');

  // Create output directory if it doesn't exist
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    console.log(`✅ Created directory: ${OUTPUT_DIR}\n`);
  }

  // Check if input image exists
  if (!fs.existsSync(INPUT_IMAGE)) {
    console.error(`❌ Error: Input image not found at ${INPUT_IMAGE}`);
    process.exit(1);
  }

  console.log(`📷 Source image: ${INPUT_IMAGE}\n`);

  // Generate standard icons
  console.log('Generating standard icons:');
  for (const { size, name } of ICON_SIZES) {
    const outputPath = path.join(OUTPUT_DIR, name);
    
    try {
      await sharp(INPUT_IMAGE)
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toFile(outputPath);
      
      console.log(`  ✓ ${name} (${size}x${size})`);
    } catch (error) {
      console.error(`  ✗ Failed to generate ${name}:`, error.message);
    }
  }

  // Generate maskable icons (with padding for safe zone)
  console.log('\nGenerating maskable icons (with safe zone):');
  for (const { size, name } of MASKABLE_SIZES) {
    const outputPath = path.join(OUTPUT_DIR, name);
    const padding = Math.floor(size * 0.1); // 10% padding for safe zone
    const iconSize = size - (padding * 2);
    
    try {
      await sharp(INPUT_IMAGE)
        .resize(iconSize, iconSize, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .extend({
          top: padding,
          bottom: padding,
          left: padding,
          right: padding,
          background: { r: 102, g: 126, b: 234, alpha: 1 } // Theme color #667eea
        })
        .png()
        .toFile(outputPath);
      
      console.log(`  ✓ ${name} (${size}x${size} with ${padding}px padding)`);
    } catch (error) {
      console.error(`  ✗ Failed to generate ${name}:`, error.message);
    }
  }

  console.log('\n✅ All PWA icons generated successfully!');
  console.log(`📁 Output directory: ${OUTPUT_DIR}`);
}

// Run the script
generateIcons().catch((error) => {
  console.error('❌ Error generating icons:', error);
  process.exit(1);
});

