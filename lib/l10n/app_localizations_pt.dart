// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get navTrack => 'Rastreio';

  @override
  String get navMap => 'Mapa';

  @override
  String get navLog => 'Registo';

  @override
  String get navTrails => 'Trilhos';

  @override
  String get navStats => 'Estatísticas';

  @override
  String get trackAppBarTitle => 'Rastrear Caminhada';

  @override
  String get trackTileLat => 'LAT';

  @override
  String get trackTileLon => 'LON';

  @override
  String get trackTileAlt => 'ALT';

  @override
  String get trackTileTime => 'TEMPO';

  @override
  String get trackTileDist => 'DIST';

  @override
  String get trackTilePts => 'PTS';

  @override
  String get trackTileTemp => 'TEMP';

  @override
  String get trackTileWeather => 'TEMPO';

  @override
  String get trackTilePressure => 'PRESSÃO';

  @override
  String get trackTileSteps => 'PASSOS';

  @override
  String get trackTileKcal => 'KCAL';

  @override
  String get trackTileSpeed => 'VEL.';

  @override
  String get trackTileGps => 'GPS';

  @override
  String get trackStartHike => 'Iniciar Caminhada';

  @override
  String get trackStopAndSave => 'Parar e Guardar';

  @override
  String get trackSaving => 'A guardar...';

  @override
  String get trackRecording => 'A gravar...';

  @override
  String get trackPause => 'Pausar';

  @override
  String get trackResume => 'Retomar';

  @override
  String get trackPaused => 'Pausado';

  @override
  String get trackHikeSaved => 'Caminhada guardada!';

  @override
  String get trackNotAvailable => 'N/D';

  @override
  String get logAppBarTitle => 'Registo de Caminhadas';

  @override
  String logAppBarTitleCount(int count) {
    return 'Registo ($count)';
  }

  @override
  String get logSortOldestFirst => 'Mais antigo primeiro';

  @override
  String get logSortNewestFirst => 'Mais recente primeiro';

  @override
  String get logEmptyTitle => 'Ainda sem caminhadas';

  @override
  String get logEmptySubtitle => 'Comece a registar a sua primeira caminhada!';

  @override
  String get logSaveToTrailsDialogTitle => 'Guardar em Trilhos';

  @override
  String get logSaveToTrailsFieldLabel => 'Nome do trilho';

  @override
  String logSavedToTrails(String name) {
    return 'Guardado em Trilhos como \'$name\'';
  }

  @override
  String get logDeleteDialogTitle => 'Eliminar Caminhada?';

  @override
  String logDeleteDialogContent(String name) {
    return 'Eliminar \"$name\"?';
  }

  @override
  String get logSaveToTrailsTooltip => 'Guardar em Trilhos';

  @override
  String get detailNoRoute => 'Sem rota registada';

  @override
  String get detailLabelDate => 'Data';

  @override
  String get detailLabelStart => 'Início';

  @override
  String get detailLabelEnd => 'Fim';

  @override
  String get detailLabelDuration => 'Duração';

  @override
  String get detailLabelDistance => 'Distância';

  @override
  String get detailLabelGpsPoints => 'Pontos GPS';

  @override
  String get detailLabelNoGpsPoints => 'Sem pontos GPS';

  @override
  String get detailLabelSteps => 'Passos';

  @override
  String get detailLabelCalories => 'Calorias';

  @override
  String get trailsAppBarTitle => 'Navegador de Trilhos';

  @override
  String trailsSelectionCount(int count) {
    return '$count selecionados';
  }

  @override
  String get trailsSortAtoZ => 'A → Z';

  @override
  String get trailsSortZtoA => 'Z → A';

  @override
  String get trailsCancelSelection => 'Cancelar seleção';

  @override
  String get trailsSelectAll => 'Selecionar tudo';

  @override
  String get trailsDeselectAll => 'Desmarcar tudo';

  @override
  String get trailsExportTooltip => 'Exportar trilhos';

  @override
  String get trailsImportTooltip => 'Importar GPX / KML / XML';

  @override
  String get trailsShareMenuItem => 'Partilhar';

  @override
  String get trailsSaveToDeviceMenuItem => 'Guardar no dispositivo';

  @override
  String get trailsEmptyState =>
      'Sem trilhos importados. Toque em + para importar um ficheiro GPX, KML ou XML.';

  @override
  String get trailsDeleteDialogTitle => 'Eliminar trilho?';

  @override
  String trailsDeleteDialogContent(String name) {
    return 'Remover \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get trailsStartHikeTooltip => 'Iniciar caminhada neste trilho';

  @override
  String get trailsFullScreenTooltip => 'Ecrã completo';

  @override
  String get trailsCloseTooltip => 'Fechar';

  @override
  String trailsImportSuccess(int count, int files) {
    return 'Importados $count trilho(s) de $files ficheiro(s)';
  }

  @override
  String get trailsNoTrailsSelected => 'Nenhum trilho selecionado.';

  @override
  String get trailsNoTrailsToExport => 'Sem trilhos para exportar.';

  @override
  String get trailsStoragePermissionRequired =>
      'Permissão de armazenamento necessária para guardar ficheiros';

  @override
  String trailsSavedToPath(String path) {
    return 'Guardado em $path';
  }

  @override
  String get statsAppBarTitle => 'Estatísticas';

  @override
  String get statsAboutMenuItem => 'Sobre';

  @override
  String get statsSectionSummary => 'Resumo';

  @override
  String get statsSectionPersonalBests => 'Melhores Marcas';

  @override
  String get statsSectionStreaks => 'Sequências';

  @override
  String get statsSectionDistanceByMonth => 'Distância por Mês';

  @override
  String get statsSectionActivityByDay => 'Atividade por Dia da Semana';

  @override
  String get statsSectionDistributionTitle => 'Distribuição de Distância';

  @override
  String get statsMetricTotalHikes => 'Total de Caminhadas';

  @override
  String get statsMetricTotalDistance => 'Distância Total';

  @override
  String get statsMetricTotalTime => 'Tempo Total';

  @override
  String get statsMetricAvgDistance => 'Distância Média';

  @override
  String get statsMetricAvgDuration => 'Duração Média';

  @override
  String get statsMetricAvgPace => 'Ritmo Médio';

  @override
  String get statsMetricLongestDistance => 'Mais Longa (distância)';

  @override
  String get statsMetricLongestDuration => 'Mais Longa (duração)';

  @override
  String get statsMetricTotalSteps => 'Total de Passos';

  @override
  String get statsMetricBestDistance => 'Melhor Distância';

  @override
  String get statsMetricBestPace => 'Melhor Ritmo';

  @override
  String get statsMetricMostActiveWeek => 'Semana Mais Ativa';

  @override
  String statsMetricMostActiveWeekValue(int count) {
    return '$count caminhadas';
  }

  @override
  String get statsMetricMostSteps => 'Mais Passos';

  @override
  String get statsMetricCurrentStreak => 'Sequência Atual';

  @override
  String get statsMetricLongestStreak => 'Maior Sequência';

  @override
  String statsStreakDays(int count) {
    return '$count dias';
  }

  @override
  String get statsEmptyPeriod => 'Sem caminhadas neste período';

  @override
  String get statsEmptyNoHikes => 'Ainda sem caminhadas registadas';

  @override
  String get statsNoData => 'Sem dados para este período';

  @override
  String get statsRetry => 'Tentar novamente';

  @override
  String get statsDistributionAxisLabel => 'km por caminhada';

  @override
  String get statsFilterPreset7d => '7 d';

  @override
  String get statsFilterPreset30d => '30 d';

  @override
  String get statsFilterPreset3mo => '3 meses';

  @override
  String get statsFilterPresetAll => 'Todos';

  @override
  String get statsDateStart => 'Início';

  @override
  String get statsDateToday => 'Hoje';

  @override
  String get splashRecoveryDialogTitle => 'Caminhada Inacabada Encontrada';

  @override
  String splashRecoveryName(String name) {
    return 'Nome: $name';
  }

  @override
  String splashRecoveryStarted(String time) {
    return 'Iniciada: $time';
  }

  @override
  String splashRecoveryPoints(int count) {
    return 'Pontos GPS: $count';
  }

  @override
  String get splashRecoveryQuestion =>
      'Deseja retomar ou descartar esta caminhada?';

  @override
  String get splashRecoveryResume => 'Retomar';

  @override
  String get splashRecoveryDiscard => 'Descartar';

  @override
  String get aboutTagline => 'Ferramentas essenciais para caminhadas.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonErrorStopCurrentHike =>
      'Pare a caminhada atual antes de iniciar uma nova.';

  @override
  String get trackBgLocationDenied =>
      'Para rastreio com ecrã desligado, permita o acesso à localização \"Sempre\" nas Definições.';

  @override
  String trailsImportSkipped(int count) {
    return '$count ignorado(s): formato não suportado';
  }

  @override
  String trailsImportFailed(int count) {
    return '$count falhou ao analisar';
  }

  @override
  String get trailsExportingDialogLabel => 'A exportar trilhos...';

  @override
  String get trailsSavingDialogLabel => 'A guardar trilhos...';

  @override
  String trackErrorCouldNotStart(String detail) {
    return 'Não foi possível iniciar o registo: $detail';
  }

  @override
  String get trackErrorCouldNotSave =>
      'Não foi possível guardar a caminhada. Tente novamente.';

  @override
  String get trackErrorCouldNotResume =>
      'Não foi possível retomar a caminhada. Tente novamente.';
}
