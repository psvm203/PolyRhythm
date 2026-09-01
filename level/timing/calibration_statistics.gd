class_name CalibrationStatistics
extends RefCounted


static func median(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) * 0.5


static func mean_deviation(samples: Array[float], center: float) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for sample in samples:
		total += absf(sample - center)
	return total / samples.size()


static func reject_outliers(samples: Array[float]) -> Array[float]:
	if samples.size() < 4:
		return samples.duplicate()
	var center := median(samples)
	var deviations: Array[float] = []
	for sample in samples:
		deviations.append(absf(sample - center))
	var mad := median(deviations)
	var limit := maxf(mad * 3.0, 8.0)
	var filtered: Array[float] = []
	for sample in samples:
		if absf(sample - center) <= limit:
			filtered.append(sample)
	return filtered


static func report(samples: Array[float], devices: Array[String] = []) -> Dictionary:
	var filtered := reject_outliers(samples)
	var center := median(filtered)
	var device_samples := {}
	for index in samples.size():
		var device := devices[index] if index < devices.size() else "unknown"
		if not device_samples.has(device):
			device_samples[device] = []
		(device_samples[device] as Array).append(samples[index])
	var device_centers := {}
	for device in device_samples:
		var typed_samples: Array[float] = []
		for sample in device_samples[device]:
			typed_samples.append(float(sample))
		device_centers[device] = median(reject_outliers(typed_samples))
	return {
		"center_ms": center,
		"spread_ms": mean_deviation(filtered, center),
		"sample_count": samples.size(),
		"accepted_count": filtered.size(),
		"rejected_count": samples.size() - filtered.size(),
		"device_centers_ms": device_centers,
	}
