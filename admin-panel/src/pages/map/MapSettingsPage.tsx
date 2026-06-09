import { useState, useCallback, useRef, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  GoogleMap, useJsApiLoader, Polygon, Marker, OverlayView,
} from '@react-google-maps/api';
import type { Libraries } from '@react-google-maps/api';
import {
  Save, MapPin, Eye, EyeOff, AlertTriangle, Info,
  Plus, Trash2, Pencil, Check, X, Move,
  Minus, Home, Maximize2, Crosshair,
} from 'lucide-react';
import { mapSettingsApi } from '../../api/mapSettings';
import { getApiErrorMessage } from '../../api';
import { InfoTooltip } from '../../components/ui/InfoTooltip';
import { useToast } from '../../components/ui/Toast';
import { Header } from '../../components/layout/Header';

// ── Types ─────────────────────────────────────────────────────────────────────
interface BoundaryZone {
  id:     string;
  name:   string;
  points: google.maps.LatLngLiteral[];
}

// ── Constants ─────────────────────────────────────────────────────────────────
const KWARA_CENTER: google.maps.LatLngLiteral = { lat: 8.4966, lng: 4.5421 };

const KWARA_BOUNDS: google.maps.LatLngBoundsLiteral = {
  north: 9.95, south: 7.40, east: 6.60, west: 2.85,
};

const KWARA_OUTLINE: google.maps.LatLngLiteral[] = [
  { lat: 9.733, lng: 3.367 }, { lat: 9.883, lng: 4.050 },
  { lat: 9.750, lng: 4.717 }, { lat: 9.583, lng: 5.233 },
  { lat: 9.100, lng: 5.817 }, { lat: 8.567, lng: 6.483 },
  { lat: 8.083, lng: 6.150 }, { lat: 7.700, lng: 5.867 },
  { lat: 7.583, lng: 5.167 }, { lat: 7.750, lng: 4.583 },
  { lat: 7.900, lng: 3.933 }, { lat: 8.083, lng: 3.267 },
  { lat: 8.567, lng: 3.050 }, { lat: 9.150, lng: 2.967 },
  { lat: 9.733, lng: 3.367 },
];

// Each zone gets a colour from this palette (wraps if more than 6 zones)
const ZONE_COLORS = ['#2563eb', '#16a34a', '#dc2626', '#9333ea', '#ea580c', '#0891b2'];

const LIBRARIES: Libraries = [];
const MAP_CONTAINER_STYLE = { width: '100%', height: '100%' };
const MAP_OPTIONS: google.maps.MapOptions = {
  mapTypeControl:    true,
  streetViewControl: false,
  fullscreenControl: true,
  zoomControl:       false,   // replaced with custom controls below
  restriction: { latLngBounds: KWARA_BOUNDS, strictBounds: true },
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function clampToKwara(lat: number, lng: number): google.maps.LatLngLiteral {
  return {
    lat: Math.max(KWARA_BOUNDS.south, Math.min(KWARA_BOUNDS.north, lat)),
    lng: Math.max(KWARA_BOUNDS.west,  Math.min(KWARA_BOUNDS.east,  lng)),
  };
}

/** Migrate old single-polygon format [{lat,lng}] → BoundaryZone[] */
function parseBoundary(raw: string): BoundaryZone[] {
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed) || parsed.length === 0) return [];
    if ('lat' in parsed[0] && 'lng' in parsed[0]) {
      return [{ id: 'zone_legacy', name: 'Zone 1', points: parsed }];
    }
    return parsed as BoundaryZone[];
  } catch { return []; }
}

function uid() { return `zone_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`; }

// ── Panel UI helpers ──────────────────────────────────────────────────────────
function Section({ title, help, children }: { title: string; help?: string; children: React.ReactNode }) {
  return (
    <div className="border-b border-slate-200 pb-4 mb-4 last:border-0 last:mb-0 last:pb-0">
      <div className="flex items-center gap-1.5 mb-3">
        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">{title}</p>
        {help && <InfoTooltip content={help} size={12} />}
      </div>
      {children}
    </div>
  );
}
function FieldRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 mb-2 last:mb-0">
      <span className="text-sm text-slate-600 shrink-0">{label}</span>
      <div className="flex-1 text-right">{children}</div>
    </div>
  );
}

// ── MapCanvas ─────────────────────────────────────────────────────────────────
interface MapCanvasProps {
  apiKey:            string;
  center:            google.maps.LatLngLiteral;
  zoom:              number;
  showKwara:         boolean;
  zones:             BoundaryZone[];
  activeZoneId:      string | null;
  isDrawing:         boolean;
  onMapLoad:         (map: google.maps.Map) => void;
  onZonePolygonLoad: (id: string, poly: google.maps.Polygon) => void;
  onZoneClick:       (id: string) => void;
  onCenterChange:    (pt: google.maps.LatLngLiteral) => void;
  onZoomChanged:     () => void;
  onDrawingComplete: (pts: google.maps.LatLngLiteral[]) => void;
  onDrawingCancel:   () => void;
  onMarkerDragEnd:   (pt: google.maps.LatLngLiteral) => void;
}

function MapCanvas({
  apiKey, center, zoom, showKwara, zones, activeZoneId, isDrawing,
  onMapLoad, onZonePolygonLoad, onZoneClick,
  onCenterChange, onZoomChanged, onDrawingComplete, onDrawingCancel, onMarkerDragEnd,
}: MapCanvasProps) {
  const { isLoaded, loadError } = useJsApiLoader({ googleMapsApiKey: apiKey, libraries: LIBRARIES });

  const [mapInst,  setMapInst]  = useState<google.maps.Map | null>(null);
  const [polyMap,  setPolyMap]  = useState<Record<string, google.maps.Polygon>>({});
  const [draftPts, setDraftPts] = useState<google.maps.LatLngLiteral[]>([]);

  // Always-fresh refs for stable event listeners
  const isDrawingRef   = useRef(isDrawing);
  const onCenterRef    = useRef(onCenterChange);
  isDrawingRef.current = isDrawing;
  onCenterRef.current  = onCenterChange;

  // ── Map click → add draft point OR set center ─────────────────────────────
  useEffect(() => {
    if (!mapInst) return;
    const l = google.maps.event.addListener(mapInst, 'click', (e: google.maps.MapMouseEvent) => {
      if (!e.latLng) return;
      const pt = clampToKwara(e.latLng.lat(), e.latLng.lng());
      if (isDrawingRef.current) setDraftPts(prev => [...prev, pt]);
      else onCenterRef.current(pt);
    });
    return () => { google.maps.event.removeListener(l); };
  }, [mapInst]);

  // ── Cursor / zoom toggle during drawing ───────────────────────────────────
  useEffect(() => {
    if (!mapInst) return;
    mapInst.setOptions({
      draggableCursor:        isDrawing ? 'crosshair' : '',
      disableDoubleClickZoom: isDrawing,
    });
  }, [mapInst, isDrawing]);

  // ── Clear draft when drawing cancelled ───────────────────────────────────
  useEffect(() => { if (!isDrawing) setDraftPts([]); }, [isDrawing]);

  // ── Clamping listeners for all loaded polygons ────────────────────────────
  useEffect(() => {
    const listeners: google.maps.MapsEventListener[] = [];
    Object.values(polyMap).forEach(poly => {
      const path = poly.getPath();
      const clampV = (i: number) => {
        const v = path.getAt(i);
        const c = clampToKwara(v.lat(), v.lng());
        if (c.lat !== v.lat() || c.lng !== v.lng())
          path.setAt(i, new google.maps.LatLng(c.lat, c.lng));
      };
      const clampAll = () => { for (let i = 0; i < path.getLength(); i++) clampV(i); };
      listeners.push(
        google.maps.event.addListener(path, 'set_at',    (i: number) => clampV(i)),
        google.maps.event.addListener(path, 'insert_at', (i: number) => clampV(i)),
        google.maps.event.addListener(poly, 'dragend',   clampAll),
      );
    });
    return () => { listeners.forEach(l => google.maps.event.removeListener(l)); };
  }, [polyMap]);

  const handleMapLoad = useCallback((map: google.maps.Map) => {
    setMapInst(map); onMapLoad(map);
  }, [onMapLoad]);

  const handlePolyLoad = useCallback((id: string, poly: google.maps.Polygon) => {
    setPolyMap(prev => ({ ...prev, [id]: poly }));
    onZonePolygonLoad(id, poly);
  }, [onZonePolygonLoad]);

  const finishDrawing = useCallback(() => {
    if (draftPts.length >= 3) { onDrawingComplete(draftPts); setDraftPts([]); }
  }, [draftPts, onDrawingComplete]);

  const cancelDrawing = useCallback(() => { setDraftPts([]); onDrawingCancel(); }, [onDrawingCancel]);
  const undoPoint     = useCallback(() => { setDraftPts(prev => prev.slice(0, -1)); }, []);

  const onDraftDrag = useCallback((i: number, e: google.maps.MapMouseEvent) => {
    if (!e.latLng) return;
    const c = clampToKwara(e.latLng.lat(), e.latLng.lng());
    setDraftPts(prev => { const n = [...prev]; n[i] = c; return n; });
  }, []);

  if (loadError) return (
    <div className="absolute inset-0 flex items-center justify-center bg-slate-100 text-red-600 text-sm">
      Failed to load Google Maps — check your API key.
    </div>
  );
  if (!isLoaded) return (
    <div className="absolute inset-0 flex items-center justify-center bg-slate-100 text-slate-500 text-sm">
      <div className="flex flex-col items-center gap-3">
        <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-brand-600" />
        <span>Loading map…</span>
      </div>
    </div>
  );

  return (
    <>
      <GoogleMap
        mapContainerStyle={MAP_CONTAINER_STYLE}
        center={center} zoom={zoom}
        onLoad={handleMapLoad}
        onZoomChanged={onZoomChanged}
        options={MAP_OPTIONS}
      >
        {/* Kwara outline */}
        {showKwara && (
          <Polygon paths={KWARA_OUTLINE} options={{
            strokeColor: '#f97316', strokeOpacity: 0.8, strokeWeight: 2,
            fillColor: '#f97316', fillOpacity: 0.05, clickable: false, zIndex: 1,
          }} />
        )}

        {/* All boundary zones */}
        {!isDrawing && zones.map((zone, i) => {
          const color    = ZONE_COLORS[i % ZONE_COLORS.length];
          const isActive = zone.id === activeZoneId;
          return (
            <Polygon
              key={`${zone.id}-${zone.points.length}`}
              paths={zone.points}
              editable={isActive}
              draggable={isActive}
              onLoad={poly => handlePolyLoad(zone.id, poly)}
              onClick={() => onZoneClick(zone.id)}
              options={{
                strokeColor:   color,
                strokeOpacity: 0.9,
                strokeWeight:  isActive ? 3 : 2,
                fillColor:     color,
                fillOpacity:   isActive ? 0.18 : 0.08,
                zIndex:        isActive ? 4 : 2,
                // cursor is not a valid PolygonOptions field — handled via CSS on the container
              }}
            />
          );
        })}

        {/* Zone name labels */}
        {!isDrawing && zones.map((zone, i) => {
          if (!zone.points.length) return null;
          const mid = zone.points[Math.floor(zone.points.length / 2)];
          return (
            <OverlayView key={`lbl-${zone.id}`} position={mid} mapPaneName={OverlayView.OVERLAY_MOUSE_TARGET}>
              <div
                onClick={() => onZoneClick(zone.id)}
                className="pointer-events-auto cursor-pointer select-none text-xs font-bold px-2 py-0.5 rounded-full shadow border whitespace-nowrap -translate-x-1/2 -translate-y-1/2"
                style={{ color: ZONE_COLORS[i % ZONE_COLORS.length], borderColor: ZONE_COLORS[i % ZONE_COLORS.length], background: 'white' }}
              >
                {zone.name}
              </div>
            </OverlayView>
          );
        })}

        {/* Draft polygon */}
        {isDrawing && draftPts.length >= 2 && (
          <Polygon paths={draftPts} options={{
            strokeColor: '#2563eb', strokeOpacity: 0.6, strokeWeight: 2,
            fillColor: '#3b82f6', fillOpacity: 0.08, clickable: false, zIndex: 5,
          }} />
        )}

        {/* Draft markers — draggable */}
        {isDrawing && draftPts.map((pt, i) => (
          <Marker key={i} position={pt} draggable
            onDragEnd={e => onDraftDrag(i, e)}
            title={i === 0 ? 'First point' : `Point ${i + 1}`}
            icon={{
              path: google.maps.SymbolPath.CIRCLE,
              fillColor:    i === 0 ? '#16a34a' : '#2563eb',
              fillOpacity:  1, strokeColor: '#fff', strokeWeight: 2,
              scale: i === 0 ? 8 : 6,
            }}
          />
        ))}

        {/* Default center marker */}
        {!isDrawing && (
          <Marker
            position={center} draggable
            onDragEnd={e => { if (e.latLng) onMarkerDragEnd(clampToKwara(e.latLng.lat(), e.latLng.lng())); }}
            title="Default map center — drag to reposition"
            icon={{
              path: google.maps.SymbolPath.CIRCLE,
              fillColor: '#f97316', fillOpacity: 1,
              strokeColor: '#fff', strokeWeight: 2, scale: 8,
            }}
          />
        )}

        {/* Kwara label */}
        {showKwara && (
          <OverlayView position={{ lat: 9.5, lng: 4.55 }} mapPaneName={OverlayView.OVERLAY_MOUSE_TARGET}>
            <div className="pointer-events-none text-xs font-semibold text-orange-600 bg-white/80 px-1.5 py-0.5 rounded shadow-sm border border-orange-200 whitespace-nowrap">
              Kwara State
            </div>
          </OverlayView>
        )}
      </GoogleMap>

      {/* ── Custom map controls (right side) ── */}
      {mapInst && (
        <div className="absolute top-4 right-4 z-10 flex flex-col items-center gap-1.5">

          {/* Zoom in / level / zoom out */}
          <div className="flex flex-col items-center rounded-xl overflow-hidden shadow-md border border-slate-200 bg-white">
            <button
              onClick={() => mapInst.setZoom(Math.min(18, (mapInst.getZoom() ?? zoom) + 1))}
              title="Zoom in"
              className="w-9 h-9 flex items-center justify-center text-slate-700 hover:bg-brand-50 hover:text-brand-700 transition-colors border-b border-slate-100"
            >
              <Plus size={16} />
            </button>
            <div className="w-9 py-1.5 text-center text-[11px] font-mono text-slate-500 border-b border-slate-100 select-none">
              {zoom}
            </div>
            <button
              onClick={() => mapInst.setZoom(Math.max(6, (mapInst.getZoom() ?? zoom) - 1))}
              title="Zoom out"
              className="w-9 h-9 flex items-center justify-center text-slate-700 hover:bg-brand-50 hover:text-brand-700 transition-colors"
            >
              <Minus size={16} />
            </button>
          </div>

          {/* Reset view — centres on Kwara at default zoom */}
          <button
            onClick={() => { mapInst.setCenter(KWARA_CENTER); mapInst.setZoom(9); }}
            title="Reset to Kwara overview"
            className="w-9 h-9 bg-white rounded-xl shadow-md border border-slate-200 flex items-center justify-center text-slate-500 hover:bg-brand-50 hover:text-brand-700 transition-colors"
          >
            <Home size={15} />
          </button>

          {/* Fit all zones — only shown when at least one zone is drawn */}
          {zones.some(z => z.points.length >= 3) && (
            <button
              onClick={() => {
                const bounds = new google.maps.LatLngBounds();
                zones.forEach(z => z.points.forEach(p => bounds.extend(p)));
                mapInst.fitBounds(bounds, 60);
              }}
              title="Fit map to all boundary zones"
              className="w-9 h-9 bg-white rounded-xl shadow-md border border-slate-200 flex items-center justify-center text-slate-500 hover:bg-brand-50 hover:text-brand-700 transition-colors"
            >
              <Maximize2 size={14} />
            </button>
          )}

          {/* Centre on active zone */}
          {activeZoneId && zones.find(z => z.id === activeZoneId && z.points.length >= 3) && (
            <button
              onClick={() => {
                const zone = zones.find(z => z.id === activeZoneId)!;
                const bounds = new google.maps.LatLngBounds();
                zone.points.forEach(p => bounds.extend(p));
                mapInst.fitBounds(bounds, 80);
              }}
              title="Zoom to selected zone"
              className="w-9 h-9 bg-white rounded-xl shadow-md border border-blue-200 flex items-center justify-center text-blue-500 hover:bg-blue-50 transition-colors"
            >
              <Crosshair size={14} />
            </button>
          )}
        </div>
      )}

      {/* Drawing instruction bar */}
      {isDrawing && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-10 flex items-center gap-2 bg-white rounded-xl shadow-lg border border-slate-200 px-4 py-2.5 whitespace-nowrap">
          <span className="text-sm text-slate-600">
            {draftPts.length === 0 ? 'Click the map to place the first point'
              : draftPts.length < 3 ? `${draftPts.length} pt${draftPts.length > 1 ? 's' : ''} — add ${3 - draftPts.length} more`
              : `${draftPts.length} points — ready`}
          </span>
          {draftPts.length > 0 && (
            <button onClick={undoPoint}
              className="text-slate-500 text-xs px-2.5 py-1.5 rounded-lg border border-slate-200 hover:bg-slate-50 transition-colors">
              Undo
            </button>
          )}
          {draftPts.length >= 3 && (
            <button onClick={finishDrawing}
              className="bg-brand-600 text-white text-xs font-semibold px-3 py-1.5 rounded-lg hover:bg-brand-500 transition-colors">
              Finish
            </button>
          )}
          <button onClick={cancelDrawing}
            className="text-slate-500 text-xs px-2.5 py-1.5 rounded-lg hover:bg-slate-100 transition-colors">
            Cancel
          </button>
        </div>
      )}

      {/* Legend */}
      {!isDrawing && (
        <div className="absolute bottom-6 left-4 bg-white rounded-xl shadow-lg border border-slate-200 px-4 py-3 text-xs space-y-1.5 pointer-events-none">
          {showKwara && (
            <div className="flex items-center gap-2">
              <span className="inline-block w-4 h-0 border-t-2 border-orange-400 opacity-70" />
              <span className="text-slate-600">Kwara State outline</span>
            </div>
          )}
          {zones.map((z, i) => (
            <div key={z.id} className="flex items-center gap-2">
              <span className="inline-block w-3 h-3 rounded-sm" style={{ background: ZONE_COLORS[i % ZONE_COLORS.length] + '33', border: `2px solid ${ZONE_COLORS[i % ZONE_COLORS.length]}` }} />
              <span className="text-slate-600">{z.name}</span>
            </div>
          ))}
          <div className="flex items-center gap-2 pt-0.5">
            <span className="inline-block w-3 h-3 rounded-full bg-orange-500 border-2 border-white shadow" />
            <span className="text-slate-600">Default center</span>
          </div>
        </div>
      )}
    </>
  );
}

// ── Zone list item ─────────────────────────────────────────────────────────────
function ZoneItem({
  zone, index, isActive, isEditing,
  onSelect, onRedraw, onDelete,
  onEditName, onSaveName, onCancelName,
  nameValue, onNameChange,
}: {
  zone: BoundaryZone; index: number; isActive: boolean; isEditing: boolean;
  onSelect: () => void; onRedraw: () => void; onDelete: () => void;
  onEditName: () => void; onSaveName: () => void; onCancelName: () => void;
  nameValue: string; onNameChange: (v: string) => void;
}) {
  const color = ZONE_COLORS[index % ZONE_COLORS.length];
  return (
    <div
      onClick={onSelect}
      className={`group flex items-center gap-2 rounded-xl px-3 py-2.5 cursor-pointer transition-colors border ${
        isActive ? 'bg-brand-50 border-brand-200' : 'bg-white border-slate-200 hover:bg-slate-50'
      }`}
    >
      {/* Color dot */}
      <span className="flex-shrink-0 h-3 w-3 rounded-full border-2 border-white shadow"
        style={{ background: color }} />

      {/* Name / edit field */}
      <div className="flex-1 min-w-0" onClick={e => e.stopPropagation()}>
        {isEditing ? (
          <div className="flex items-center gap-1">
            <input
              autoFocus
              value={nameValue}
              onChange={e => onNameChange(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') onSaveName(); if (e.key === 'Escape') onCancelName(); }}
              className="flex-1 min-w-0 text-xs rounded border border-brand-300 px-1.5 py-0.5 focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
            <button onClick={onSaveName} className="text-green-600 hover:text-green-700"><Check size={13} /></button>
            <button onClick={onCancelName} className="text-slate-400 hover:text-slate-600"><X size={13} /></button>
          </div>
        ) : (
          <p className="text-xs font-medium text-slate-800 truncate">{zone.name}</p>
        )}
        <p className="text-[10px] text-slate-400">{zone.points.length} points</p>
      </div>

      {/* Actions */}
      {!isEditing && (
        <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity" onClick={e => e.stopPropagation()}>
          <button onClick={onEditName} title="Rename" className="p-1 rounded hover:bg-slate-200 text-slate-500 hover:text-slate-700">
            <Pencil size={12} />
          </button>
          <button onClick={onRedraw} title="Redraw" className="p-1 rounded hover:bg-blue-100 text-blue-500 hover:text-blue-700">
            <Move size={12} />
          </button>
          <button onClick={onDelete} title="Delete" className="p-1 rounded hover:bg-red-100 text-red-400 hover:text-red-600">
            <Trash2 size={12} />
          </button>
        </div>
      )}
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export function MapSettingsPage() {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['admin-settings'],
    queryFn:  mapSettingsApi.get,
  });

  const [apiKey,          setApiKey]          = useState('');
  const [apiKeyInput,     setApiKeyInput]     = useState('');
  const [serverKeyInput,  setServerKeyInput]  = useState('');
  const [showApiKey,      setShowApiKey]      = useState(false);
  const [showServerKey,   setShowServerKey]   = useState(false);
  const [enforcement,  setEnforcement]  = useState(false);
  const [showKwara,    setShowKwara]    = useState(true);
  const [center,       setCenter]       = useState<google.maps.LatLngLiteral>(KWARA_CENTER);
  const [zoom,         setZoom]         = useState(9);
  const [zones,        setZones]        = useState<BoundaryZone[]>([]);
  const [activeZoneId, setActiveZoneId] = useState<string | null>(null);
  const [isDrawing,    setIsDrawing]    = useState(false);
  const [drawingFor,   setDrawingFor]   = useState<string | null>(null); // null = new zone
  const [editingId,    setEditingId]    = useState<string | null>(null);
  const [editingName,  setEditingName]  = useState('');

  const polygonRefs = useRef<Record<string, google.maps.Polygon>>({});
  const mapRef      = useRef<google.maps.Map | null>(null);

  useEffect(() => {
    if (!settings) return;
    const key = settings.google_maps_web_key ?? settings.google_maps_api_key ?? '';
    setApiKey(key); setApiKeyInput(key);
    setServerKeyInput(settings.google_maps_server_key ?? '');
    setEnforcement(settings.booking_boundary_enforcement === '1');
    setCenter({
      lat: parseFloat(settings.map_center_lat ?? String(KWARA_CENTER.lat)),
      lng: parseFloat(settings.map_center_lng ?? String(KWARA_CENTER.lng)),
    });
    setZoom(parseInt(settings.map_default_zoom ?? '9', 10));
    setZones(parseBoundary(settings.service_boundary ?? '[]'));
  }, [settings]);

  const { mutate: save, isPending: saving } = useMutation({
    mutationFn: () => {
      // Collect current paths from live polygon objects (captures all edits)
      const saved = zones.map(z => ({
        id:   z.id,
        name: z.name,
        points: polygonRefs.current[z.id]
          ? polygonRefs.current[z.id].getPath().getArray()
              .map(p => clampToKwara(p.lat(), p.lng()))
          : z.points,
      }));
      return mapSettingsApi.save({
        google_maps_api_key:          apiKeyInput.trim(),
        google_maps_web_key:          apiKeyInput.trim(),
        google_maps_server_key:       serverKeyInput.trim(),
        map_center_lat:               String(center.lat),
        map_center_lng:               String(center.lng),
        map_default_zoom:             String(zoom),
        service_boundary:             JSON.stringify(saved),
        booking_boundary_enforcement: enforcement ? '1' : '0',
      });
    },
    onSuccess: () => {
      const trimmed = apiKeyInput.trim();
      if (trimmed !== apiKey) setApiKey(trimmed);
      queryClient.invalidateQueries({ queryKey: ['admin-settings'] });
      toast('Map settings saved.', 'success');
    },
    onError: (err: unknown) => toast(getApiErrorMessage(err), 'error'),
  });

  const onMapLoad          = useCallback((map: google.maps.Map) => { mapRef.current = map; }, []);
  const onZonePolygonLoad  = useCallback((id: string, poly: google.maps.Polygon) => { polygonRefs.current[id] = poly; }, []);
  const onZoneClick        = useCallback((id: string) => { setActiveZoneId(prev => prev === id ? null : id); }, []);
  const onCenterChange     = useCallback((pt: google.maps.LatLngLiteral) => setCenter(pt), []);
  const onZoomChanged      = useCallback(() => { if (mapRef.current) setZoom(mapRef.current.getZoom() ?? zoom); }, [zoom]);
  const onMarkerDragEnd    = useCallback((pt: google.maps.LatLngLiteral) => setCenter(pt), []);
  const onDrawingCancel    = useCallback(() => { setIsDrawing(false); setDrawingFor(null); }, []);

  const onDrawingComplete  = useCallback((pts: google.maps.LatLngLiteral[]) => {
    if (drawingFor) {
      // Replace points of an existing zone
      setZones(prev => prev.map(z => z.id === drawingFor ? { ...z, points: pts } : z));
      setActiveZoneId(drawingFor);
    } else {
      // Add new zone
      const id   = uid();
      const name = `Zone ${zones.length + 1}`;
      setZones(prev => [...prev, { id, name, points: pts }]);
      setActiveZoneId(id);
    }
    setIsDrawing(false);
    setDrawingFor(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [drawingFor, zones.length]);

  const addZone = () => { setDrawingFor(null); setIsDrawing(true); setActiveZoneId(null); };

  const redrawZone = (id: string) => {
    setZones(prev => prev.map(z => z.id === id ? { ...z, points: [] } : z));
    delete polygonRefs.current[id];
    setDrawingFor(id);
    setIsDrawing(true);
    setActiveZoneId(null);
  };

  const deleteZone = (id: string) => {
    polygonRefs.current[id]?.setMap(null);
    delete polygonRefs.current[id];
    setZones(prev => prev.filter(z => z.id !== id));
    if (activeZoneId === id) setActiveZoneId(null);
  };

  const startEditName = (zone: BoundaryZone) => {
    setEditingId(zone.id);
    setEditingName(zone.name);
  };
  const saveName = () => {
    if (editingName.trim()) setZones(prev => prev.map(z => z.id === editingId ? { ...z, name: editingName.trim() } : z));
    setEditingId(null);
  };
  const cancelName = () => setEditingId(null);

  if (isLoading) return (
    <div className="flex flex-col h-full">
      <Header title="Map Settings" subtitle="Configure service area and map options" />
      <div className="flex-1 flex items-center justify-center">
        <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-brand-600" />
      </div>
    </div>
  );

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <Header title="Map Settings" subtitle="Configure service area and map options" />

      <div className="flex flex-1 overflow-hidden">

        {/* ── Left panel ── */}
        <aside className="w-80 shrink-0 border-r border-slate-200 bg-white overflow-y-auto p-5 flex flex-col gap-0">

          <Section title="Google Maps API Keys"
            help="Use a WEB key for the admin dashboard map (restrict by HTTP referrers), and a SERVER key for backend proxy calls like geocoding/places (restrict by server IP).">
            <div className="relative mb-2">
              <input
                type={showApiKey ? 'text' : 'password'}
                value={apiKeyInput}
                onChange={e => setApiKeyInput(e.target.value)}
                placeholder="AIza…"
                className="w-full rounded-lg border border-slate-200 px-3 py-2 pr-9 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <button type="button" onClick={() => setShowApiKey(s => !s)}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                {showApiKey ? <EyeOff size={14} /> : <Eye size={14} />}
              </button>
            </div>
            <div className="relative mb-2">
              <input
                type={showServerKey ? 'text' : 'password'}
                value={serverKeyInput}
                onChange={e => setServerKeyInput(e.target.value)}
                placeholder="Server key (optional if using legacy key)"
                className="w-full rounded-lg border border-slate-200 px-3 py-2 pr-9 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <button type="button" onClick={() => setShowServerKey(s => !s)}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                {showServerKey ? <EyeOff size={14} /> : <Eye size={14} />}
              </button>
            </div>
            {!apiKey && (
              <p className="flex items-start gap-1.5 text-xs text-amber-600">
                <AlertTriangle size={12} className="shrink-0 mt-0.5" />
                Enter your key and save to load the map.
              </p>
            )}
          </Section>

          <Section title="Default View"
            help="The default center and zoom level is what customers see when they first open the map in the app before they search for a location. Drag the orange dot on the map or click anywhere to reposition it.">
            <FieldRow label="Center latitude">
              <span className="text-sm font-mono text-slate-800">{center.lat.toFixed(5)}</span>
            </FieldRow>
            <FieldRow label="Center longitude">
              <span className="text-sm font-mono text-slate-800">{center.lng.toFixed(5)}</span>
            </FieldRow>
            <FieldRow label="Zoom level">
              <span className="text-sm font-mono text-slate-800">{zoom}</span>
            </FieldRow>
            <p className="flex items-start gap-1.5 text-xs text-slate-500 mt-2">
              <Info size={12} className="shrink-0 mt-0.5" />
              Click map or drag the orange dot to set center. Scroll to set zoom.
            </p>
          </Section>

          <Section title="Service Boundaries"
            help="A service boundary is a zone where trips are allowed. You can draw multiple zones — e.g. Ilorin City, Offa, Jebba. When enforcement is ON, bookings with pickup or dropoff outside ALL zones are rejected. Click a zone on the map or in the list to select it for editing.">
            <div className="space-y-2 mb-3">
              {zones.map((z, i) => (
                <ZoneItem
                  key={z.id}
                  zone={z} index={i}
                  isActive={activeZoneId === z.id}
                  isEditing={editingId === z.id}
                  onSelect={() => setActiveZoneId(prev => prev === z.id ? null : z.id)}
                  onRedraw={() => redrawZone(z.id)}
                  onDelete={() => deleteZone(z.id)}
                  onEditName={() => startEditName(z)}
                  onSaveName={saveName}
                  onCancelName={cancelName}
                  nameValue={editingName}
                  onNameChange={setEditingName}
                />
              ))}

              {zones.length === 0 && (
                <p className="text-xs text-slate-400 text-center py-2">No boundaries drawn yet.</p>
              )}
            </div>

            <button type="button" disabled={!apiKey} onClick={addZone}
              className="w-full flex items-center justify-center gap-2 rounded-lg border border-dashed border-brand-300 bg-brand-50 hover:bg-brand-100 text-brand-700 text-xs font-medium px-3 py-2 transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
              <Plus size={13} />
              Add boundary zone
            </button>

            {zones.length > 0 && activeZoneId && (
              <div className="mt-2 rounded-xl bg-blue-50 border border-blue-100 px-3 py-2.5 space-y-1">
                <div className="flex items-center gap-1.5 text-xs font-medium text-blue-700">
                  <Move size={11} /> Editing selected zone
                </div>
                <ul className="text-xs text-blue-600 space-y-0.5 list-disc list-inside">
                  <li>Drag a vertex to move it</li>
                  <li>Click mid-point to add vertex</li>
                  <li>Right-click vertex to delete it</li>
                  <li>Drag inside polygon to move all</li>
                </ul>
              </div>
            )}

            <button type="button" onClick={() => setShowKwara(s => !s)}
              className="flex items-center gap-2 text-xs text-slate-500 hover:text-slate-700 transition-colors mt-3">
              {showKwara ? <Eye size={12} /> : <EyeOff size={12} />}
              {showKwara ? 'Hide' : 'Show'} Kwara State outline
            </button>
          </Section>

          <Section title="Booking Enforcement"
            help="When ON, the API checks the pickup and dropoff of every new booking against your boundary zones. If neither point falls inside any zone, the booking is rejected with a clear error message. When OFF, the zones are shown on the map but have no effect on bookings.">
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm text-slate-700">Block bookings outside boundaries</span>
              <button type="button" role="switch" aria-checked={enforcement}
                onClick={() => setEnforcement(s => !s)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${enforcement ? 'bg-brand-600' : 'bg-slate-300'}`}>
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${enforcement ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </label>
            {enforcement && zones.length === 0 && (
              <p className="flex items-start gap-1.5 text-xs text-amber-600 mt-2">
                <AlertTriangle size={12} className="shrink-0 mt-0.5" />
                Draw at least one boundary for enforcement to work.
              </p>
            )}
            {!enforcement && (
              <p className="text-xs text-slate-400 mt-2">Boundaries visible on map but not enforced.</p>
            )}
          </Section>

          <div className="mt-auto pt-2">
            <button type="button" onClick={() => save()} disabled={saving}
              className="w-full flex items-center justify-center gap-2 rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-sm font-semibold py-3 transition-colors disabled:opacity-60">
              <Save size={15} />
              {saving ? 'Saving…' : 'Save Map Settings'}
            </button>
          </div>
        </aside>

        {/* ── Map area ── */}
        <div className="flex-1 relative">
          {!apiKey ? (
            <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-slate-100 text-slate-500">
              <MapPin size={40} className="text-slate-300" />
              <p className="text-sm">Enter a Google Maps API key and save to load the map.</p>
            </div>
          ) : (
            <MapCanvas
              key={apiKey}
              apiKey={apiKey}
              center={center} zoom={zoom}
              showKwara={showKwara}
              zones={zones.filter(z => z.points.length >= 3)}
              activeZoneId={activeZoneId}
              isDrawing={isDrawing}
              onMapLoad={onMapLoad}
              onZonePolygonLoad={onZonePolygonLoad}
              onZoneClick={onZoneClick}
              onCenterChange={onCenterChange}
              onZoomChanged={onZoomChanged}
              onDrawingComplete={onDrawingComplete}
              onDrawingCancel={onDrawingCancel}
              onMarkerDragEnd={onMarkerDragEnd}
            />
          )}
        </div>
      </div>
    </div>
  );
}
